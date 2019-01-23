"""Manages the details of the websocket connection. """

import asyncio
import concurrent
import os
import sys
import time
import traceback
import websockets

import iterm2.api_pb2
from iterm2._version import __version__

def _getenv(key):
    """Gets an environment variable safely.

    Returns None if it does not exist.
    """
    if key in os.environ:
        return os.environ[key]
    else:
        return None

def _cookie_and_key():
    cookie = _getenv('ITERM2_COOKIE')
    key = _getenv('ITERM2_KEY')
    return cookie, key

def _headers():
    cookie, key = _cookie_and_key()
    headers = {"origin": "ws://localhost/",
               "x-iterm2-library-version": "python {}".format(__version__)}
    if cookie is not None:
        headers["x-iterm2-cookie"] = cookie
    if key is not None:
        headers["x-iterm2-key"] = key
    return headers

def _uri():
    return "ws://localhost:1912"

def _subprotocols():
    return ['api.iterm2.com']

class Connection:
    """Represents a loopback network connection from the script to iTerm2.

    Provides functionality for sending and receiving messages. Supports
    dispatching incoming messages."""
    helpers = []
    @staticmethod
    def register_helper(helper):
        """
        Registers a function that handles incoming messages.

        You probably don't want to call this. It's used internally for dispatching
        notifications.

        Arguments:
          helper: A coroutine that will be called on incoming messages that were not
            previously handled.
        """
        assert helper is not None
        Connection.helpers.append(helper)

    @staticmethod
    async def async_create():
        """Creates a new connection.

        This is intended for use in an apython REPL. It constructs a new
        connection and returns it without creating an asyncio event loop.
        """
        connection = Connection()
        cookie, key = _cookie_and_key()
        connection.websocket = await websockets.connect(_uri(), extra_headers=_headers(), subprotocols=_subprotocols())
        connection.__dispatch_forever_future = asyncio.ensure_future(connection._async_dispatch_forever(connection, asyncio.get_event_loop()))
        return connection

    def __init__(self):
        self.websocket = None
        # A list of tuples of (matchFunc, future). When a message is received
        # each matchFunc is called with the message as an argument. The first
        # one that returns true gets its future's result set with that message.
        # If none returns True it is dispatched through the helpers. Typically
        # that would be a notification.
        self.__receivers = []

    def _collect_garbage(self):
        """Asyncio seems to want you to keep a reference to a task that's begin
        run with ensure_future. If you don't, it says "task was destroyed but
        it is still pending". So, ok, we'll keep references around until we
        don't need to any more."""
        self.__tasks = list(filter(lambda t: not t.done(), self.__tasks))

    def run_until_complete(self, coro):
        self.run(False, coro)

    def run_forever(self, coro):
        self.run(True, coro)

    def set_message_in_future(self, loop, message, future):
        assert future is not None
        # Is the response to an RPC that is being awaited.
        def setResult():
            assert future is not None
            if not future.done():
                future.set_result(message)
        loop.call_soon(setResult)

    async def _async_dispatch_forever(self, connection, loop):
        """Read messages from websocket and call helpers or message responders."""
        self.__tasks = []
        try:
            while True:
                data = await self.websocket.recv()
                self._collect_garbage()

                message = iterm2.api_pb2.ServerOriginatedMessage()
                message.ParseFromString(data)

                future = self._get_receiver_future(message)
                # Note that however we decide to handle this message,
                # it must be done *after* we await on the websocket.
                # Otherwise we might never get the chance.
                if future is None:
                    # May be a notification.
                    self.__tasks.append(asyncio.ensure_future(self._async_dispatch_to_helper(message)))
                else:
                    self.set_message_in_future(loop, message, future)
        except concurrent.futures._base.CancelledError:
            # Presumably a run_until_complete script
            pass
        except:
            # I'm not quite sure why this is necessary, but if we don't
            # catch and re-raise the exception it gets swallowed.
            traceback.print_exc()
            raise

    def run(self, forever, coro):
        """
        Convenience method to start a program.

        Connects to the API endpoint, begins an asyncio event loop, and runs the
        passed in coroutine. Exceptions will be caught and printed to stdout.

        :param coro: A coroutine (async function) to run after connecting.
        """
        loop = asyncio.get_event_loop()

        async def async_main(connection):
            dispatch_forever_task = asyncio.ensure_future(self._async_dispatch_forever(connection, loop))
            await coro(connection)
            if forever:
                await dispatch_forever_task
            dispatch_forever_task.cancel()

        # This keeps you from pulling your hair out. The downside is uncertain, but
        # I do know that pulling my hair out hurts.
        loop.set_debug(True)
        self.loop = loop
        loop.run_until_complete(self.async_connect(async_main))


    async def async_send_message(self, message):
        """
        Sends a message.

        This is a low-level operation that is not generally called by user code.

        message: A protocol buffer of type iterm2.api_pb2.ClientOriginatedMessage to send.
        """
        await self.websocket.send(message.SerializeToString())

    def _receiver_index(self, message):
        """Searches __receivers for the receiver that should handle message and returns its index."""
        for i in range(len(self.__receivers)):
            matchFunc = self.__receivers[i][0]
            if matchFunc and matchFunc(message):
                return i
        # This says that the first receiver always gets the message if no other receiver can handle it.
        return None

    def _get_receiver_future(self, message):
        """Removes the receiver for message and returns its future."""
        i = self._receiver_index(message)
        if i is None:
            return None
        matchFunc, future = self.__receivers[i]
        del self.__receivers[i]
        return future

    async def async_dispatch_until_id(self, reqid):
        """
        Handle incoming messages until one with the specified id is received.

        Messages not having the expected id get dispatched asynchronously by a
        registered helper if one exists.

        You probably don't want to use this. It's used while waiting for the
        response to an RPC, and has logic specific that that use.

        reqid: The request ID to look for.

        Returns: A message with the specified request id.
        """
        my_future = asyncio.Future()
        def matchFunc(m):
            return m.id == reqid
        my_receiver = (matchFunc, my_future)
        self.__receivers.append(my_receiver)
        return await my_future

    async def _async_dispatch_to_helper(self, message):
        """
        Dispatch a message to all registered helpers.
        """
        for helper in Connection.helpers:
            assert helper is not None
            try:
                if await helper(self, message):
                    break
            except Exception:
                raise

    async def async_connect(self, coro):
        """
        Establishes a websocket connection.

        You probably want to use Connection.run(), which takes care of runloop
        setup for you. Connects to iTerm2 on localhost. Once connected, awaits
        execution of coro.

        This uses ITERM2_COOKIE and ITERM2_KEY environment variables to help with
        authentication. ITERM2_COOKIE has a shared secret that lets user-launched
        scripts skip the auth dialog. ITERM2_KEY is used to tie together the output
        of this program with its entry in the scripting console.

        coro: A coroutine to run once connected.
        """
        async with websockets.connect(_uri(), extra_headers=_headers(), subprotocols=_subprotocols()) as websocket:
            self.websocket = websocket
            try:
                await coro(self)
            except Exception as _err:
                traceback.print_exc()
                sys.exit(1)


def run_until_complete(coro):
    """Convenience method to run an async function taking an :class:`iterm2.Connection` as an argument."""
    Connection().run_until_complete(coro)

def run_forever(coro):
    """Convenience method to run an async function taking an :class:`iterm2.Connection` as an argument."""
    Connection().run_forever(coro)
