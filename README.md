=====

#PRIMER: 

An iTerm2 interface for interactive terminal presentations.

Based on George Nachman's iTerm2 application at <a href="https://iterm2.com">iTerm2.com</a>.

Original source: https://github.com/gnachman/iTerm2


====

#NOTES

See sources/iTermApplicationDelegate.m for customised launch sequence.

Launches automatically in full-screen, removes menu items.

    ```DLog(@"application performStartupActivities finished, executing Primer commands");
    PseudoTerminal *term = [[iTermController sharedInstance] currentTerminal];
    
    DLog(@"current terminal: %@", term);
    // Enter fullscreen
    [[term ptyWindow] performSelector:@selector(toggleFullScreen:) withObject:self];
    ```

Sets a custom font and font-size

    ```DLog(@"Set font");
    // Set our font after font file copy:
    NSFont * myFont2 =[NSFont fontWithName:@"DroidSansMonoNerdFontComplete-" size:24];
    if(myFont2)
        [session setFont:myFont2 nonAsciiFont:myFont2 horizontalSpacing:1 verticalSpacing:1] ;
    ```

Runs the script specified:

       
    ```// Run default primer command:
    NSString * path = [NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] resourcePath],@"/Primer/\"\r"];
    NSString * command = [@"cd \"" stringByAppendingString:path];
    DLog(@"Set path");
    [session writeTask:command];
    DLog(@"Move to bash");
    [session writeTask:@"bash\r"];
    DLog(@"Run Primer");
    [session writeTask:@"./_primer\r"];
    ```