//
//  iTermSemanticHistoryTest.m
//  iTerm2
//
//  Created by George Nachman on 12/5/14.
//
//

#import "iTermSemanticHistoryController.h"
#import "iTermSemanticHistoryPrefsController.h"
#import "NSFileManager+iTerm.h"
#import <XCTest/XCTest.h>

@interface iTermSemanticHistoryTest : XCTestCase
@end

@interface iTermFakeFileManager : NSFileManager
@property(nonatomic, readonly) NSMutableSet *files;
@property(nonatomic, readonly) NSMutableSet *directories;
@property(nonatomic, readonly) NSMutableSet *networkMountPoints;
@end

@implementation iTermFakeFileManager

- (id)init {
    self = [super init];
    if (self) {
        _files = [[NSMutableSet alloc] init];
        _directories = [[NSMutableSet alloc] init];
        _networkMountPoints = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_files release];
    [_directories release];
    [_networkMountPoints release];
    [super dealloc];
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
    if ([_files containsObject:path]) {
        if (isDirectory) {
            *isDirectory = NO;
        }
        return YES;
    }

    if ([_directories containsObject:path]) {
        if (isDirectory) {
            *isDirectory = YES;
        }
        return YES;
    }

    return NO;
}

- (BOOL)fileExistsAtPathLocally:(NSString *)filename
         additionalNetworkPaths:(NSArray<NSString *> *)additionalNetworkPaths {
    NSMutableArray *networkPaths = [[_networkMountPoints mutableCopy] autorelease];
    [networkPaths addObjectsFromArray:additionalNetworkPaths];
    for (NSString *networkPath in networkPaths) {
        if ([filename hasPrefix:networkPath]) {
            return NO;
        }
    }

    return [self fileExistsAtPath:filename];
}

- (BOOL)fileExistsAtPath:(NSString *)path {
    return [self fileExistsAtPath:path isDirectory:NULL];
}

@end

@interface TestSemanticHistoryController : iTermSemanticHistoryController
@property(nonatomic, readonly) iTermFakeFileManager *fakeFileManager;
@property(nonatomic, copy) NSArray *scriptArguments;
@property(nonatomic, copy) NSString *openedFile;
@property(nonatomic, copy) NSURL *openedURL;
@property(nonatomic, copy) NSString *openedEditor;
@property(nonatomic, assign) BOOL defaultAppIsEditor;
@property(nonatomic, copy) NSString *launchedApp;
@property(nonatomic, copy) NSString *launchedAppArg;
@property(nonatomic, copy) NSString *bundleIdForDefaultApp;
@end

@implementation TestSemanticHistoryController

- (instancetype)init {
    self = [super init];
    if (self) {
        _fakeFileManager = [[iTermFakeFileManager alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_fakeFileManager release];
    [_scriptArguments release];
    [_openedFile release];
    [_openedURL release];
    [_openedEditor release];
    [_launchedApp release];
    [_launchedAppArg release];
    [_bundleIdForDefaultApp release];
    [super dealloc];
}

- (NSFileManager *)fileManager {
    return _fakeFileManager;
}

- (void)launchTaskWithPath:(NSString *)path arguments:(NSArray *)arguments wait:(BOOL)wait {
    self.scriptArguments = arguments;
}

- (BOOL)openFile:(NSString *)fullPath {
    self.openedFile = fullPath;
    return YES;
}

- (BOOL)openURL:(NSURL *)url editorIdentifier:(NSString *)editorIdentifier {
    self.openedURL = url;
    self.openedEditor = editorIdentifier;
    return YES;
}

- (BOOL)defaultAppForFileIsEditor:(NSString *)file {
    return _defaultAppIsEditor;
}

- (void)launchAppWithBundleIdentifier:(NSString *)bundleIdentifier path:(NSString *)path {
    self.launchedApp = bundleIdentifier;
    self.launchedAppArg = path;
}

- (NSString *)absolutePathForAppBundleWithIdentifier:(NSString *)bundleId {
    return [@"/Applications" stringByAppendingPathComponent:bundleId];
}

- (NSString *)bundleIdForDefaultAppForFile:(NSString *)file {
    if (_bundleIdForDefaultApp) {
        return _bundleIdForDefaultApp;
    } else {
        return [super bundleIdForDefaultAppForFile:file];
    }
}

@end

@interface iTermSemanticHistoryTest ()<iTermSemanticHistoryControllerDelegate>
@end

@implementation iTermSemanticHistoryTest {
    TestSemanticHistoryController *_semanticHistoryController;
    NSString *_coprocessCommand;
}

- (void)setUp {
    _semanticHistoryController = [[[TestSemanticHistoryController alloc] init] autorelease];
    _semanticHistoryController.delegate = self;
    _coprocessCommand = nil;
}

#pragma mark - Get Full Path

- (void)testGetFullPathFailsOnNil {
    XCTAssert([_semanticHistoryController cleanedUpPathFromPath:nil
                                                         suffix:nil
                                               workingDirectory:@"/"
                                            extractedLineNumber:NULL
                                                   columnNumber:NULL] == nil);
}

- (void)testGetFullPathFailsOnEmpty {
    XCTAssert([_semanticHistoryController cleanedUpPathFromPath:@""
                                                         suffix:nil
                                               workingDirectory:@"/"
                                            extractedLineNumber:NULL
                                                   columnNumber:NULL] == nil);
}

- (void)testGetFullPathFindsExistingFileAtAbsolutePath {
    NSString *lineNumber = nil;
    NSString *columnNumber = nil;
    static NSString *const kFilename = @"/path/to/file";
    static NSString *const kWorkingDirectory = @"/working/directory";
    [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
    NSString *actual = [_semanticHistoryController cleanedUpPathFromPath:kFilename
                                                                  suffix:nil
                                                        workingDirectory:kWorkingDirectory
                                                     extractedLineNumber:&lineNumber
                                                            columnNumber:&columnNumber];
    NSString *expected = kFilename;
    XCTAssert([expected isEqualToString:actual]);
    XCTAssert(lineNumber.length == 0);
}

- (void)testGetFullPathFindsExistingFileAtRelativePath {
    NSString *lineNumber = nil;
    NSString *columnNumber = nil;
    static NSString *const kRelativeFilename = @"path/to/file";
    static NSString *const kWorkingDirectory = @"/working/directory";
    NSString *kAbsoluteFilename =
        [kWorkingDirectory stringByAppendingPathComponent:kRelativeFilename];
    [_semanticHistoryController.fakeFileManager.files addObject:kAbsoluteFilename];
    NSString *actual = [_semanticHistoryController cleanedUpPathFromPath:kRelativeFilename
                                                                  suffix:nil
                                                        workingDirectory:kWorkingDirectory
                                                     extractedLineNumber:&lineNumber
                                                            columnNumber:&columnNumber];
    NSString *expected = kAbsoluteFilename;
    XCTAssert([expected isEqualToString:actual]);
    XCTAssert(lineNumber.length == 0);
}

- (void)testGetFullPathStripsDelimiters {
    for (NSString *delimiters in @[ @"()", @"<>", @"[]", @"{}", @"''", @"\"\"" ]) {
        NSString *lineNumber = nil;
        NSString *columnNumber = nil;
        static NSString *const kFilename = @"/path/to/file";
        NSString *kFilenameWithParens = [NSString stringWithFormat:@"%C%@%C", [delimiters characterAtIndex:0], kFilename, [delimiters characterAtIndex:1]];
        static NSString *const kWorkingDirectory = @"/working/directory";
        [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
        NSString *actual = [_semanticHistoryController cleanedUpPathFromPath:kFilenameWithParens
                                                                      suffix:nil
                                                            workingDirectory:kWorkingDirectory
                                                         extractedLineNumber:&lineNumber
                                                                columnNumber:&columnNumber];
        NSString *expected = kFilename;
        assert([expected isEqualToString:actual]);
        assert(lineNumber.length == 0);
    }
}

- (void)testGetFullPathStripsTrailingPunctuation {
    for (NSString *punctuation in @[ @".", @")", @",", @":" ]) {
        NSString *lineNumber = nil;
        NSString *columnNumber = nil;
        static NSString *const kFilename = @"/path/to/file";
        NSString *kFilenameWithParens = [kFilename stringByAppendingString:punctuation];
        static NSString *const kWorkingDirectory = @"/working/directory";
        [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
        NSString *actual = [_semanticHistoryController cleanedUpPathFromPath:kFilenameWithParens
                                                                      suffix:nil
                                                            workingDirectory:kWorkingDirectory
                                                         extractedLineNumber:&lineNumber
                                                                columnNumber:&columnNumber];
        NSString *expected = kFilename;
        XCTAssert([expected isEqualToString:actual]);
        XCTAssert(lineNumber.length == 0);
    }
}

- (void)testGetFullPathExtractsLineNumber {
    NSString *lineNumber = nil;
    NSString *columnNumber = nil;
    static NSString *const kFilename = @"/path/to/file";
    static NSString *const kWorkingDirectory = @"/working/directory";
    NSString *kFilenameWithLineNumber = [kFilename stringByAppendingString:@":123"];
    [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
    NSString *actual = [_semanticHistoryController cleanedUpPathFromPath:kFilenameWithLineNumber
                                                                  suffix:nil
                                                        workingDirectory:kWorkingDirectory
                                                     extractedLineNumber:&lineNumber
                                                            columnNumber:&columnNumber];
    NSString *expected = kFilename;
    XCTAssert([expected isEqualToString:actual]);
    XCTAssert(lineNumber.integerValue == 123);
}

- (void)testGetFullPathExtractsLineNumberAndIgnoresColumn {
    NSString *lineNumber = nil;
    NSString *columnNumber = nil;
    static NSString *const kFilename = @"/path/to/file";
    static NSString *const kWorkingDirectory = @"/working/directory";
    NSString *kFilenameWithLineNumber = [kFilename stringByAppendingString:@":123:456"];
    [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
    NSString *actual = [_semanticHistoryController cleanedUpPathFromPath:kFilenameWithLineNumber
                                                                  suffix:nil
                                                        workingDirectory:kWorkingDirectory
                                                     extractedLineNumber:&lineNumber
                                                            columnNumber:&columnNumber];
    NSString *expected = kFilename;
    XCTAssert([expected isEqualToString:actual]);
    XCTAssert(lineNumber.integerValue == 123);
}

- (void)testGetFullPathExtractsAlternateLineNumberAndColumnSyntax {
    NSString *lineNumber = nil;
    NSString *columnNumber = nil;
    static NSString *const kFilename = @"/path/to/file";
    static NSString *const kWorkingDirectory = @"/working/directory";
    NSString *kFilenameWithLineNumber = [kFilename stringByAppendingString:@"[123, 456]"];
    [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
    NSString *actual = [_semanticHistoryController cleanedUpPathFromPath:kFilenameWithLineNumber
                                                                  suffix:nil
                                                        workingDirectory:kWorkingDirectory
                                                     extractedLineNumber:&lineNumber
                                                            columnNumber:&columnNumber];
    NSString *expected = kFilename;
    XCTAssert([expected isEqualToString:actual]);
    XCTAssert(lineNumber.integerValue == 123);
    XCTAssert(columnNumber.integerValue == 456);
}

- (void)testGetFullPathExtractsVeryVerboseLineNumberAndColumnSyntax {
    NSString *lineNumber = nil;
    NSString *columnNumber = nil;
    static NSString *const kFilename = @"/path/to/file";
    static NSString *const kWorkingDirectory = @"/working/directory";
    [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
    NSString *actual = [_semanticHistoryController cleanedUpPathFromPath:kFilename
                                                                  suffix:@"\", line 123, column 456"
                                                        workingDirectory:kWorkingDirectory
                                                     extractedLineNumber:&lineNumber
                                                            columnNumber:&columnNumber];
    NSString *expected = kFilename;
    XCTAssert([expected isEqualToString:actual]);
    XCTAssert(lineNumber.integerValue == 123);
    XCTAssert(columnNumber.integerValue == 456);
}

- (void)testGetFullPathWithParensAndTrailingPunctuationExtractsLineNumber {
    NSString *lineNumber = nil;
    NSString *columnNumber = nil;
    static NSString *const kFilename = @"/path/to/file";
    static NSString *const kWorkingDirectory = @"/working/directory";
    NSString *kFilenameWithLineNumber = [NSString stringWithFormat:@"(%@:123.)", kFilename];
    [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
    NSString *actual = [_semanticHistoryController cleanedUpPathFromPath:kFilenameWithLineNumber
                                                                  suffix:nil
                                                        workingDirectory:kWorkingDirectory
                                                     extractedLineNumber:&lineNumber
                                                            columnNumber:&columnNumber];
    NSString *expected = kFilename;
    XCTAssert([expected isEqualToString:actual]);
    XCTAssert(lineNumber.integerValue == 123);
}

- (void)testGetFullPathFailsWithJustStrippedChars {
    NSString *lineNumber = nil;
    NSString *columnNumber = nil;
    static NSString *const kWorkingDirectory = @"/working/directory";
    static NSString *const kFilename = @"(:123.)";
    NSString *actual = [_semanticHistoryController cleanedUpPathFromPath:kFilename
                                                                  suffix:nil
                                                        workingDirectory:kWorkingDirectory
                                                     extractedLineNumber:&lineNumber
                                                            columnNumber:&columnNumber];
    XCTAssert(actual == nil);
}

- (void)testGetFullPathStandardizesDot {
    NSString *lineNumber = nil;
    NSString *columnNumber = nil;
    static NSString *const kRelativeFilename = @"./path/to/file";
    static NSString *const kWorkingDirectory = @"/working/directory";
    NSString *kAbsoluteFilename = @"/working/directory/path/to/file";
    [_semanticHistoryController.fakeFileManager.files addObject:kAbsoluteFilename];
    [_semanticHistoryController.fakeFileManager.files addObject:@"/working/directory/./path/to/file"];
    NSString *actual = [_semanticHistoryController cleanedUpPathFromPath:kRelativeFilename
                                                                  suffix:nil
                                                        workingDirectory:kWorkingDirectory
                                                     extractedLineNumber:&lineNumber
                                                            columnNumber:&columnNumber];
    NSString *expected = kAbsoluteFilename;
    XCTAssert([expected isEqualToString:actual]);
    XCTAssert(lineNumber.length == 0);
}

- (void)testGetFullPathStandardizesDotDot {
    NSString *lineNumber = nil;
    NSString *columnNumber = nil;
    static NSString *const kRelativeFilename = @"../path/to/file";
    static NSString *const kWorkingDirectory = @"/working/directory/blah";
    NSString *kAbsoluteFilename = @"/working/directory/path/to/file";
    [_semanticHistoryController.fakeFileManager.files addObject:kAbsoluteFilename];
    [_semanticHistoryController.fakeFileManager.files addObject:@"/working/directory/blah/../path/to/file"];
    NSString *actual = [_semanticHistoryController cleanedUpPathFromPath:kRelativeFilename
                                                                  suffix:nil
                                                        workingDirectory:kWorkingDirectory
                                                     extractedLineNumber:&lineNumber
                                                            columnNumber:&columnNumber];
    NSString *expected = kAbsoluteFilename;
    XCTAssert([expected isEqualToString:actual]);
    XCTAssert(lineNumber.length == 0);
}

- (void)testGetFullPathStripsLeadingASlash {
    NSString *lineNumber = nil;
    NSString *columnNumber = nil;
    static NSString *const kRelativeFilename = @"path/to/file";
    static NSString *const kWorkingDirectory = @"/working/directory";
    NSString *kAbsoluteFilename =
        [kWorkingDirectory stringByAppendingPathComponent:kRelativeFilename];
    [_semanticHistoryController.fakeFileManager.files addObject:kAbsoluteFilename];
    NSString *actual = [_semanticHistoryController cleanedUpPathFromPath:[@"a/" stringByAppendingString:kRelativeFilename]
                                                                  suffix:nil
                                                        workingDirectory:kWorkingDirectory
                                                     extractedLineNumber:&lineNumber
                                                            columnNumber:&columnNumber];
    NSString *expected = kAbsoluteFilename;
    XCTAssert([expected isEqualToString:actual]);
    XCTAssert(lineNumber.length == 0);
}

- (void)testGetFullPathStripsLeadingBSlash {
    NSString *lineNumber = nil;
    NSString *columnNumber = nil;
    static NSString *const kRelativeFilename = @"path/to/file";
    static NSString *const kWorkingDirectory = @"/working/directory";
    NSString *kAbsoluteFilename =
        [kWorkingDirectory stringByAppendingPathComponent:kRelativeFilename];
    [_semanticHistoryController.fakeFileManager.files addObject:kAbsoluteFilename];
    NSString *actual = [_semanticHistoryController cleanedUpPathFromPath:[@"b/" stringByAppendingString:kRelativeFilename]
                                                                  suffix:nil
                                                        workingDirectory:kWorkingDirectory
                                                     extractedLineNumber:&lineNumber
                                                            columnNumber:&columnNumber];
    NSString *expected = kAbsoluteFilename;
    XCTAssert([expected isEqualToString:actual]);
    XCTAssert(lineNumber.length == 0);
}

- (void)testGetFullPathRejectsNetworkPaths {
    NSString *lineNumber = nil;
    NSString *columnNumber = nil;
    static NSString *const kRelativeFilename = @"path/to/file";
    static NSString *const kWorkingDirectory = @"/working/directory";
    NSString *kAbsoluteFilename =
        [kWorkingDirectory stringByAppendingPathComponent:kRelativeFilename];
    [_semanticHistoryController.fakeFileManager.files addObject:kAbsoluteFilename];
    NSString *actual = [_semanticHistoryController cleanedUpPathFromPath:kRelativeFilename
                                                                  suffix:nil
                                                        workingDirectory:kWorkingDirectory
                                                     extractedLineNumber:&lineNumber
                                                            columnNumber:&columnNumber];
    NSString *expected = kAbsoluteFilename;
    XCTAssert([expected isEqualToString:actual]);

    [_semanticHistoryController.fakeFileManager.networkMountPoints addObject:@"/working"];
    actual = [_semanticHistoryController cleanedUpPathFromPath:kRelativeFilename
                                                        suffix:nil
                                              workingDirectory:kWorkingDirectory
                                           extractedLineNumber:&lineNumber
                                                  columnNumber:&columnNumber];
    XCTAssert(actual == nil);
}

#pragma mark - Open Path

- (void)testOpenPathRawAction {
    _semanticHistoryController.prefs =
        @{ kSemanticHistoryActionKey: kSemanticHistoryRawCommandAction,
           kSemanticHistoryTextKey: @"\\1;\\2;\\3;\\4;\\5;\\(test)" };

    NSString *kStringThatIsNotAPath = @"Prefix X Suffix:1";
    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:kStringThatIsNotAPath
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:kStringThatIsNotAPath
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/tmp",
                                                          @"test": @"User Variable" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(opened);
    NSString *expectedScript = @"Prefix\\ X\\ Suffix:1;;Prefix;Suffix;/tmp;User Variable";
    NSString *actualScript = _semanticHistoryController.scriptArguments[1];
    XCTAssert([expectedScript isEqualToString:actualScript]);
}

- (void)testOpenPathFailsIfFileDoesNotExist {
    _semanticHistoryController.prefs =
        @{ kSemanticHistoryActionKey: kSemanticHistoryBestEditorAction };
    NSString *kStringThatIsNotAPath = @"Prefix X Suffix:1";
    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:kStringThatIsNotAPath
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:kStringThatIsNotAPath
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/tmp" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(!opened);
}

- (void)testOpenPathRunsCommandActionForExistingFile {
    NSString *kCommand = @"Command";
    _semanticHistoryController.prefs =
        @{ kSemanticHistoryActionKey: kSemanticHistoryCommandAction,
           kSemanticHistoryTextKey: kCommand};
    NSString *kExistingFileAbsolutePath = @"/file/that/exists";
    [_semanticHistoryController.fakeFileManager.files addObject:kExistingFileAbsolutePath];
    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:kExistingFileAbsolutePath
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:kExistingFileAbsolutePath
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/tmp" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(opened);
    XCTAssert([kCommand isEqualToString:_semanticHistoryController.scriptArguments[1]]);
}

- (void)testOpenPathRunsCoprocessForExistingFile {
    NSString *kCommand = @"Command";
    _semanticHistoryController.prefs =
        @{ kSemanticHistoryActionKey: kSemanticHistoryCoprocessAction,
           kSemanticHistoryTextKey: kCommand};
    NSString *kExistingFileAbsolutePath = @"/file/that/exists";
    [_semanticHistoryController.fakeFileManager.files addObject:kExistingFileAbsolutePath];
    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:kExistingFileAbsolutePath
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:kExistingFileAbsolutePath
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/tmp" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(opened);
    XCTAssert([kCommand isEqualToString:_coprocessCommand]);
}

- (void)testOpenPathOpensFileForDirectoryWithURLAction {
    NSString *kCommand = @"Command";
    _semanticHistoryController.prefs =
        @{ kSemanticHistoryActionKey: kSemanticHistoryUrlAction,
           kSemanticHistoryTextKey: kCommand};
    NSString *kDirectory = @"/directory";
    [_semanticHistoryController.fakeFileManager.directories addObject:kDirectory];
    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:kDirectory
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:kDirectory
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/tmp" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(opened);
    XCTAssert([kDirectory isEqualToString:_semanticHistoryController.openedFile]);
}

- (void)testOpenPathOpensURLWithProperSubstitutions {
    _semanticHistoryController.prefs =
    @{ kSemanticHistoryActionKey: kSemanticHistoryUrlAction,
       kSemanticHistoryTextKey: @"http://foo/?pwd=\\1&line=\\2&prefix=\\3&suffix=\\4&dir=\\5&uservar=\\(test)" };

    NSString *kStringThatIsNotAPath = @"The Path:1";
    [_semanticHistoryController.fakeFileManager.files addObject:@"/The Path"];
    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:kStringThatIsNotAPath
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:kStringThatIsNotAPath
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"The Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"The Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/",
                                                          @"test": @"User Variable" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(opened);
    NSURL *expectedURL =
        [NSURL URLWithString:@"http://foo/?pwd=%2FThe%20Path&line=1&prefix=The%20Prefix&suffix=The%20Suffix&dir=%2F&uservar=User%20Variable"];
    NSURL *actualURL = _semanticHistoryController.openedURL;
    XCTAssertEqualObjects(expectedURL, actualURL);
    XCTAssert(!_semanticHistoryController.openedEditor);
}

- (void)testOpenPathOpensTextFileInEditorWhenEditorIsDefaultApp {
    _semanticHistoryController.prefs =
        @{ kSemanticHistoryActionKey: kSemanticHistoryEditorAction,
           kSemanticHistoryEditorKey: kMacVimIdentifier };
    NSString *kExistingFileAbsolutePath = @"/file/that/exists";
    [_semanticHistoryController.fakeFileManager.files addObject:kExistingFileAbsolutePath];
    _semanticHistoryController.defaultAppIsEditor = YES;
    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:kExistingFileAbsolutePath
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:kExistingFileAbsolutePath
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(opened);
    NSString *expectedUrlString = [NSString stringWithFormat:@"mvim://open?url=file://%@",
                                   [kExistingFileAbsolutePath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]]];
    XCTAssertEqualObjects(_semanticHistoryController.openedURL, [NSURL URLWithString:expectedUrlString]);
    XCTAssert([_semanticHistoryController.openedEditor isEqualToString:kMacVimIdentifier]);
}

// Open a file with a line number in the default app, which happens to be MacVim.
- (void)testOpenPathOpensTextFileInDefaultAppWithLineNumber {
    _semanticHistoryController.prefs =
      @{ kSemanticHistoryActionKey: kSemanticHistoryBestEditorAction };
    NSString *kExistingFileAbsolutePath = @"/file/that/exists";
    NSString *fileWithLineNumber = [kExistingFileAbsolutePath stringByAppendingString:@":12"];
    [_semanticHistoryController.fakeFileManager.files addObject:kExistingFileAbsolutePath];
    _semanticHistoryController.defaultAppIsEditor = YES;
    _semanticHistoryController.bundleIdForDefaultApp = kMacVimIdentifier;  // Act like macvim is the default for this kind of file

    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:fileWithLineNumber
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:fileWithLineNumber
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(opened);
    NSString *expectedUrlString = [NSString stringWithFormat:@"mvim://open?url=file://%@&line=12",
                                   [kExistingFileAbsolutePath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]]];
    XCTAssert([_semanticHistoryController.openedURL isEqualTo:[NSURL URLWithString:expectedUrlString]]);
    XCTAssert([_semanticHistoryController.openedEditor isEqualToString:kMacVimIdentifier]);
}

- (void)testOpenPathOpensTextFileInEditorWithLineNumberWhenEditorIsDefaultApp {
    _semanticHistoryController.prefs =
    @{ kSemanticHistoryActionKey: kSemanticHistoryEditorAction,
       kSemanticHistoryEditorKey: kMacVimIdentifier };
    NSString *kExistingFileAbsolutePath = @"/file/that/exists";
    NSString *fileWithLineNumber = [kExistingFileAbsolutePath stringByAppendingString:@":12"];
    [_semanticHistoryController.fakeFileManager.files addObject:kExistingFileAbsolutePath];
    _semanticHistoryController.defaultAppIsEditor = YES;
    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:fileWithLineNumber
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:fileWithLineNumber
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(opened);
    NSString *expectedUrlString = [NSString stringWithFormat:@"mvim://open?url=file://%@&line=12",
                                   [kExistingFileAbsolutePath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]]];
    XCTAssertEqualObjects(_semanticHistoryController.openedURL, [NSURL URLWithString:expectedUrlString]);
    XCTAssert([_semanticHistoryController.openedEditor isEqualToString:kMacVimIdentifier]);
}

- (void)testOpenPathOpensTextFileAtomEditor {
    _semanticHistoryController.prefs =
        @{ kSemanticHistoryActionKey: kSemanticHistoryEditorAction,
           kSemanticHistoryEditorKey: kAtomIdentifier };
    NSString *kExistingFileAbsolutePath = @"/file/that/exists";
    NSString *kExistingFileAbsolutePathWithLineNumber = [kExistingFileAbsolutePath stringByAppendingString:@":12"];
    [_semanticHistoryController.fakeFileManager.files addObject:kExistingFileAbsolutePath];
    _semanticHistoryController.defaultAppIsEditor = NO;
    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:kExistingFileAbsolutePathWithLineNumber
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:kExistingFileAbsolutePathWithLineNumber
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(opened);
    XCTAssert([kAtomIdentifier isEqualToString:_semanticHistoryController.launchedApp]);
    XCTAssert([kExistingFileAbsolutePathWithLineNumber isEqualToString:_semanticHistoryController.launchedAppArg]);
}

- (void)testOpenPathOpensTextFileAtomEditorWhenDefaultAppForThisFile {
    _semanticHistoryController.prefs =
    @{ kSemanticHistoryActionKey: kSemanticHistoryEditorAction,
       kSemanticHistoryEditorKey: kAtomIdentifier };
    NSString *kExistingFileAbsolutePath = @"/file/that/exists";
    NSString *kExistingFileAbsolutePathWithLineNumber = [kExistingFileAbsolutePath stringByAppendingString:@":12"];
    [_semanticHistoryController.fakeFileManager.files addObject:kExistingFileAbsolutePath];
    _semanticHistoryController.defaultAppIsEditor = NO;
    _semanticHistoryController.bundleIdForDefaultApp = kAtomIdentifier;  // Act like Atom is the default app for this file
    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:kExistingFileAbsolutePathWithLineNumber
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:kExistingFileAbsolutePathWithLineNumber
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(opened);
    XCTAssert([kAtomIdentifier isEqualToString:_semanticHistoryController.launchedApp]);
    XCTAssert([kExistingFileAbsolutePathWithLineNumber isEqualToString:_semanticHistoryController.launchedAppArg]);
}

- (void)testOpenPathOpensTextFileVSCodeEditor {
    _semanticHistoryController.prefs =
    @{ kSemanticHistoryActionKey: kSemanticHistoryEditorAction,
       kSemanticHistoryEditorKey: kVSCodeIdentifier };
    NSString *kExistingFileAbsolutePath = @"/file/that/exists";
    NSString *kExistingFileAbsolutePathWithLineNumber = [kExistingFileAbsolutePath stringByAppendingString:@":12:11"];
    [_semanticHistoryController.fakeFileManager.files addObject:kExistingFileAbsolutePath];
    _semanticHistoryController.defaultAppIsEditor = NO;
    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:kExistingFileAbsolutePathWithLineNumber
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:kExistingFileAbsolutePathWithLineNumber
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(opened);
    XCTAssert([kVSCodeIdentifier isEqualToString:_semanticHistoryController.launchedApp]);
    XCTAssert([kExistingFileAbsolutePathWithLineNumber isEqualToString:_semanticHistoryController.launchedAppArg]);
}

- (void)testOpenPathOpensTextFileVSCodeEditorWhenDefaultAppForThisFile {
    _semanticHistoryController.prefs =
    @{ kSemanticHistoryActionKey: kSemanticHistoryEditorAction,
       kSemanticHistoryEditorKey: kVSCodeIdentifier };
    NSString *kExistingFileAbsolutePath = @"/file/that/exists";
    NSString *kExistingFileAbsolutePathWithLineNumber = [kExistingFileAbsolutePath stringByAppendingString:@":12:11"];
    [_semanticHistoryController.fakeFileManager.files addObject:kExistingFileAbsolutePath];
    _semanticHistoryController.defaultAppIsEditor = NO;
    _semanticHistoryController.bundleIdForDefaultApp = kVSCodeIdentifier;  // Act like VSCode is the default app for this file
    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:kExistingFileAbsolutePathWithLineNumber
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:kExistingFileAbsolutePathWithLineNumber
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(opened);
    XCTAssert([kVSCodeIdentifier isEqualToString:_semanticHistoryController.launchedApp]);
    XCTAssert([kExistingFileAbsolutePathWithLineNumber isEqualToString:_semanticHistoryController.launchedAppArg]);
}

- (void)testOpenPathOpensTextFileSublimeText2Editor {
    _semanticHistoryController.prefs =
        @{ kSemanticHistoryActionKey: kSemanticHistoryEditorAction,
           kSemanticHistoryEditorKey: kSublimeText2Identifier };
    NSString *kExistingFileAbsolutePath = @"/file/that/exists";
    NSString *kExistingFileAbsolutePathWithLineNumber =[kExistingFileAbsolutePath stringByAppendingString:@":12"];
    [_semanticHistoryController.fakeFileManager.files addObject:kExistingFileAbsolutePath];
    _semanticHistoryController.defaultAppIsEditor = NO;
    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:kExistingFileAbsolutePathWithLineNumber
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:kExistingFileAbsolutePathWithLineNumber
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(opened);
    XCTAssert([kSublimeText2Identifier isEqualToString:_semanticHistoryController.launchedApp]);
    XCTAssert([kExistingFileAbsolutePathWithLineNumber isEqualToString:_semanticHistoryController.launchedAppArg]);
}

- (void)testOpenPathOpensTextFileSublimeText3Editor {
    _semanticHistoryController.prefs =
        @{ kSemanticHistoryActionKey: kSemanticHistoryEditorAction,
           kSemanticHistoryEditorKey: kSublimeText3Identifier };
    NSString *kExistingFileAbsolutePath = @"/file/that/exists";
    NSString *kExistingFileAbsolutePathWithLineNumber =[kExistingFileAbsolutePath stringByAppendingString:@":12"];
    [_semanticHistoryController.fakeFileManager.files addObject:kExistingFileAbsolutePath];
    _semanticHistoryController.defaultAppIsEditor = NO;
    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:kExistingFileAbsolutePathWithLineNumber
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:kExistingFileAbsolutePathWithLineNumber
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(opened);
    XCTAssert([kSublimeText3Identifier isEqualToString:_semanticHistoryController.launchedApp]);
    XCTAssert([kExistingFileAbsolutePathWithLineNumber isEqualToString:_semanticHistoryController.launchedAppArg]);
}

- (void)openTextFileInEditorWithIdentifier:(NSString *)editorId
                            expectedScheme:(NSString *)expectedScheme {
    _semanticHistoryController.prefs =
        @{ kSemanticHistoryActionKey: kSemanticHistoryEditorAction,
           kSemanticHistoryEditorKey: editorId };
    NSString *kExistingFileAbsolutePath = @"/file/that/exists";
    NSString *kLineNumber = @":12";
    NSString *kExistingFileAbsolutePathWithLineNumber =
        [kExistingFileAbsolutePath stringByAppendingString:kLineNumber];
    [_semanticHistoryController.fakeFileManager.files addObject:kExistingFileAbsolutePath];
    _semanticHistoryController.defaultAppIsEditor = NO;
    NSString *lineNumber, *columnNumber;
    BOOL opened = [_semanticHistoryController openPath:[_semanticHistoryController cleanedUpPathFromPath:kExistingFileAbsolutePathWithLineNumber
                                                                                                  suffix:nil
                                                                                        workingDirectory:@"/"
                                                                                     extractedLineNumber:&lineNumber
                                                                                            columnNumber:&columnNumber]
                                         orRawFilename:kExistingFileAbsolutePathWithLineNumber
                                         substitutions:@{ kSemanticHistoryPrefixSubstitutionKey: @"Prefix",
                                                          kSemanticHistorySuffixSubstitutionKey: @"Suffix",
                                                          kSemanticHistoryWorkingDirectorySubstitutionKey: @"/" }
                                            lineNumber:lineNumber
                                          columnNumber:columnNumber];
    XCTAssert(opened);
    NSString *urlString =
        [NSString stringWithFormat:@"%@://open?url=file://%@&line=%@",
            expectedScheme, [kExistingFileAbsolutePath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]], [kLineNumber substringFromIndex:1]];
    NSURL *expectedURL = [NSURL URLWithString:urlString];
    XCTAssertEqualObjects(_semanticHistoryController.openedURL, expectedURL);
    XCTAssert([_semanticHistoryController.openedEditor isEqual:editorId]);
}

- (void)testOpenPathOpensTextFileInMacVim {
    [self openTextFileInEditorWithIdentifier:kMacVimIdentifier expectedScheme:@"mvim"];
}

- (void)testOpenPathOpensTextFileInTextMate {
    [self openTextFileInEditorWithIdentifier:kTextmateIdentifier expectedScheme:@"txmt"];
}

- (void)testOpenPathOpensTextFileInBBEdit {
    // Sadly, BBEdit uses textmate's scheme. This is intentional.
    [self openTextFileInEditorWithIdentifier:kBBEditIdentifier expectedScheme:@"txmt"];
}

// Note there is no test for textmate 2 because it is not directly selectable from the menu and it
// uses the same scheme as textmate, even though its identifier is different.

#pragma mark - Path Of Existing File

- (void)testPathOfExistingFile_Local {
    int numCharsFromPrefix;
    int numCharsFromSuffix;
    NSString *kWorkingDirectory = @"/directory";
    NSString *kRelativeFilename = @"five six seven eight";
    NSString *kFilename = [kWorkingDirectory stringByAppendingPathComponent:kRelativeFilename];
    [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
    [_semanticHistoryController.fakeFileManager.directories addObject:kWorkingDirectory];
    NSString *path = [_semanticHistoryController pathOfExistingFileFoundWithPrefix:@"one two three four five six "
                                                                            suffix:@"seven eight nine ten eleven"
                                                                  workingDirectory:kWorkingDirectory
                                                              charsTakenFromPrefix:&numCharsFromPrefix
                                                              charsTakenFromSuffix:&numCharsFromSuffix
                                                                    trimWhitespace:NO];
    XCTAssert([kRelativeFilename isEqualToString:path]);
    XCTAssert(numCharsFromPrefix == [@"five six " length]);
}

// This test simulates what happens if you select a full line (including hard eol) and do Open Selection.
// The prefix will end in whitespace (maybe) and a newline. This test uses whitespace trimming.
- (void)testPathOfExistingFileIgnoringLeadingAndTrailingWhitespaceAndNewlines {
  int numCharsFromPrefix;
  int numCharsFromSuffix;
  NSString *kWorkingDirectory = @"/directory";
  NSString *kRelativeFilename = @"five six seven eight";
  NSString *kFilename = [kWorkingDirectory stringByAppendingPathComponent:kRelativeFilename];
  [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
  [_semanticHistoryController.fakeFileManager.directories addObject:kWorkingDirectory];
  NSString *path = [_semanticHistoryController pathOfExistingFileFoundWithPrefix:@"five six seven eight \r\n"
                                                                          suffix:@""
                                                                workingDirectory:kWorkingDirectory
                                                            charsTakenFromPrefix:&numCharsFromPrefix
                                                            charsTakenFromSuffix:&numCharsFromSuffix
                                                                  trimWhitespace:YES];
  XCTAssert([kRelativeFilename isEqualToString:path]);
    XCTAssert(numCharsFromPrefix == [@"five six seven eight" length]);
    XCTAssert(numCharsFromSuffix == [@"" length]);
}

- (void)testPathOfExistingFileRemovesParens {
    int numCharsFromPrefix;
    int numCharsFromSuffix;
    NSString *kWorkingDirectory = @"/directory";
    NSString *kRelativeFilename = @"five six seven eight";
    NSString *kFilename = [kWorkingDirectory stringByAppendingPathComponent:kRelativeFilename];
    [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
    [_semanticHistoryController.fakeFileManager.directories addObject:kWorkingDirectory];
    NSString *path = [_semanticHistoryController pathOfExistingFileFoundWithPrefix:@"one two three four (five six "
                                                                            suffix:@"seven eight) nine ten eleven"
                                                                  workingDirectory:kWorkingDirectory
                                                              charsTakenFromPrefix:&numCharsFromPrefix
                                                              charsTakenFromSuffix:&numCharsFromSuffix
                                                                    trimWhitespace:NO];
    XCTAssert([@"five six seven eight" isEqualToString:path]);
    XCTAssert(numCharsFromPrefix == [@"five six " length]);
    XCTAssert(numCharsFromSuffix == [@"seven eight" length]);
}

- (void)testPathOfExistingFileSupportsLineNumberAndColumnNumber {
    int numCharsFromPrefix;
    int numCharsFromSuffix;
    NSString *kWorkingDirectory = @"/directory";
    NSString *kRelativeFilename = @"five six seven eight";
    NSString *kFilename = [kWorkingDirectory stringByAppendingPathComponent:kRelativeFilename];
    [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
    [_semanticHistoryController.fakeFileManager.directories addObject:kWorkingDirectory];
    NSString *path = [_semanticHistoryController pathOfExistingFileFoundWithPrefix:@"one two three four five six "
                                                                            suffix:@"seven eight:123:456 nine ten eleven"
                                                                  workingDirectory:kWorkingDirectory
                                                              charsTakenFromPrefix:&numCharsFromPrefix
                                                              charsTakenFromSuffix:&numCharsFromSuffix
                                                                    trimWhitespace:NO];
    XCTAssert([@"five six seven eight:123:456" isEqualToString:path]);
    XCTAssert(numCharsFromPrefix == [@"five six " length]);
    XCTAssert(numCharsFromSuffix == [@"seven eight:123:456" length]);
}

- (void)testPathOfExistingFileSupportsLineNumberAndColumnNumberAndParensAndNonspaceSeparators {
    int numCharsFromPrefix;
    int numCharsFromSuffix;
    NSString *kWorkingDirectory = @"/directory";
    NSString *kRelativeFilename = @"five.six\tseven eight";
    NSString *kFilename = [kWorkingDirectory stringByAppendingPathComponent:kRelativeFilename];
    [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
    [_semanticHistoryController.fakeFileManager.directories addObject:kWorkingDirectory];
    NSString *path = [_semanticHistoryController pathOfExistingFileFoundWithPrefix:@"one two three four (five.six\t"
                                                                            suffix:@"seven eight:123:456). nine ten eleven"
                                                                  workingDirectory:kWorkingDirectory
                                                              charsTakenFromPrefix:&numCharsFromPrefix
                                                              charsTakenFromSuffix:&numCharsFromSuffix
                                                                    trimWhitespace:NO];
    XCTAssert([@"five.six\tseven eight:123:456" isEqualToString:path]);
    XCTAssert(numCharsFromPrefix == [@"five.six\t" length]);
    XCTAssert(numCharsFromSuffix == [@"seven eight:123:456" length]);
}

- (void)testPathOfExistingFile_IgnoresFilesOnNetworkVolumes {
    int numCharsFromPrefix;
    int numCharsFromSuffix;
    NSString *kWorkingDirectory = @"/directory";
    NSString *kRelativeFilename = @"five six seven eight";
    NSString *kFilename = [kWorkingDirectory stringByAppendingPathComponent:kRelativeFilename];
    [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
    [_semanticHistoryController.fakeFileManager.networkMountPoints addObject:kWorkingDirectory];
    [_semanticHistoryController.fakeFileManager.directories addObject:kWorkingDirectory];
    NSString *path = [_semanticHistoryController pathOfExistingFileFoundWithPrefix:@"one two three four five six "
                                                                            suffix:@"seven eight nine ten eleven"
                                                                  workingDirectory:kWorkingDirectory
                                                              charsTakenFromPrefix:&numCharsFromPrefix
                                                              charsTakenFromSuffix:&numCharsFromSuffix
                                                                    trimWhitespace:NO];
    XCTAssert(path == nil);
}

// Regression test for issue 3841.
- (void)testLeadingWhitespaceIgnoredWithoutTrimming {
    int numCharsFromPrefix;
    int numCharsFromSuffix;
    NSString *kWorkingDirectory = @"/directory";
    NSString *kRelativeFilename = @"test.txt";
    NSString *kFilename = [kWorkingDirectory stringByAppendingPathComponent:kRelativeFilename];
    [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
    [_semanticHistoryController.fakeFileManager.directories addObject:kWorkingDirectory];
    NSString *path = [_semanticHistoryController pathOfExistingFileFoundWithPrefix:@"     "
                                                                            suffix:@"  test.txt"
                                                                  workingDirectory:kWorkingDirectory
                                                              charsTakenFromPrefix:&numCharsFromPrefix
                                                              charsTakenFromSuffix:&numCharsFromSuffix
                                                                    trimWhitespace:NO];
    XCTAssert(path == nil);
}

// Regression test for issue 4927
- (void)testPathOfExistingFile_EscapedCharacters {
    int numCharsFromPrefix;
    int numCharsFromSuffix;
    NSString *kWorkingDirectory = @"/directory";
    NSString *kRelativeFilename = @"five six seven eight";
    NSString *kFilename = [kWorkingDirectory stringByAppendingPathComponent:kRelativeFilename];
    [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
    [_semanticHistoryController.fakeFileManager.directories addObject:kWorkingDirectory];
    NSString *path = [_semanticHistoryController pathOfExistingFileFoundWithPrefix:@"one two three four five\\ six\\ "
                                                                            suffix:@"seven\\ eight nine ten eleven"
                                                                  workingDirectory:kWorkingDirectory
                                                              charsTakenFromPrefix:&numCharsFromPrefix
                                                              charsTakenFromSuffix:&numCharsFromSuffix
                                                                    trimWhitespace:NO];
    XCTAssert([kRelativeFilename isEqualToString:path]);
    XCTAssert(numCharsFromPrefix == [@"five\\ six\\ " length]);
    XCTAssert(numCharsFromSuffix == [@"seven\\ eight" length]);
}


#warning This test fails, but fixing it would change how raw actions work in edge cases where there is punctuation or brackets. I'll delay that until 3.1.
#if 0
- (void)testPathOfExistingFile_QuestionableSuffix {
    int numCharsFromPrefix;
    int numCharsFromSuffix;
    NSString *kWorkingDirectory = @"/directory";
    NSString *kRelativeFilename = @"five six seven eight";
    NSString *kFilename = [kWorkingDirectory stringByAppendingPathComponent:kRelativeFilename];
    [_semanticHistoryController.fakeFileManager.files addObject:kFilename];
    [_semanticHistoryController.fakeFileManager.directories addObject:kWorkingDirectory];
    NSString *path = [_semanticHistoryController pathOfExistingFileFoundWithPrefix:@"one two three four five six "
                                                                            suffix:@"seven eight. nine ten eleven"
                                                                  workingDirectory:kWorkingDirectory
                                                              charsTakenFromPrefix:&numCharsFromPrefix
                                                              charsTakenFromSuffix:&numCharsFromSuffix
                                                                    trimWhitespace:NO];
    XCTAssert([kRelativeFilename isEqualToString:path]);
    XCTAssert(numCharsFromPrefix == [@"five six " length]);
    XCTAssert(numCharsFromSuffix == [@"seven eight" length]);
}
#endif

#pragma mark - iTermSemanticHistoryControllerDelegate

- (void)semanticHistoryLaunchCoprocessWithCommand:(NSString *)command {
    _coprocessCommand = [[command copy] autorelease];
}

@end
