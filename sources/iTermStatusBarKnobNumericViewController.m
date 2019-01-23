//
//  iTermStatusBarKnobNumericViewController.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 6/30/18.
//

#import "iTermStatusBarKnobNumericViewController.h"

#import "NSObject+iTerm.h"

@interface iTermStatusBarKnobNumericViewController ()

@end

@implementation iTermStatusBarKnobNumericViewController

- (void)viewDidLoad {
    self.view.autoresizesSubviews = NO;
    self.value = _value;
}

- (void)setValue:(NSNumber *)value {
    _value = value;
    _stepper.doubleValue = _value.doubleValue;
    _textField.doubleValue = _value.doubleValue;
}

- (IBAction)stepperAction:(id)sender {
    self.value = @([(NSControl *)sender doubleValue]);
}

- (void)controlTextDidChange:(NSNotification *)obj {
    self.value = @([(NSControl *)obj.object doubleValue]);
}

- (void)setDescription:(NSString *)description placeholder:(nonnull NSString *)placeholder {
    _label.stringValue = description;
    [self sizeToFit];
}

- (void)sizeToFit {
    const CGFloat marginBetweenLabelAndField = NSMinX(_textField.frame) - NSMaxX(_label.frame);
    const CGFloat marginBetweenTextFieldAndStepper = NSMinX(_stepper.frame) - NSMaxX(_textField.frame);

    [_label sizeToFit];
    NSRect rect = _label.frame;
    _label.frame = rect;

    rect = _textField.frame;
    rect.origin.x = NSMaxX(_label.frame) + marginBetweenLabelAndField;
    _textField.frame = rect;

    rect = _stepper.frame;
    rect.origin.x = NSMaxX(_textField.frame) + marginBetweenTextFieldAndStepper;
    _stepper.frame = rect;

    rect = self.view.frame;
    rect.size.width = NSMaxX(_stepper.frame);
    self.view.frame = rect;
}

- (CGFloat)controlOffset {
    return NSMinX(_textField.frame);
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector {
    if ([self respondsToSelector:commandSelector]) {
        [self it_performNonObjectReturningSelector:commandSelector withObject:control];
        return YES;
    } else {
        return NO;
    }
}

- (void)insertNewline:(id)sender {
    [self.view.window.sheetParent endSheet:self.view.window returnCode:NSModalResponseOK];
}

@end

