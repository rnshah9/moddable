/*
 * Copyright (c) 2016-2022 Moddable Tech, Inc.
 *
 *   This file is part of the Moddable SDK Tools.
 * 
 *   The Moddable SDK Tools is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 * 
 *   The Moddable SDK Tools is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 * 
 *   You should have received a copy of the GNU General Public License
 *   along with the Moddable SDK Tools.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import <Cocoa/Cocoa.h>
#include <dlfcn.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include "screen.h"

NSString* gPixelFormatNames[pixelFormatCount] = {
	@"16-bit RGB 565 Little Endian",
	@"16-bit RGB 565 Big Endian",
	@"8-bit Gray",
	@"8-bit RGB 332",
	@"4-bit Gray",
	@"4-bit Color Look-up Table",
};

@interface Mockup : NSObject {
	NSMenuItem *item;
	NSString *name;
}
@property (retain) NSMenuItem *item;
@property (retain) NSString *name;
@end

@implementation Mockup
@synthesize item;
@synthesize name;
- (void)dealloc {
    [name release];
    [item release];
    [super dealloc];
}
- (NSComparisonResult)compare:(Mockup*) mockup {
	return [self.name caseInsensitiveCompare:mockup.name];
}
@end

@interface TouchFinger : NSObject {
	id identity;
	NSPoint point;
}
@property (retain) id identity;
@property (assign) NSPoint point;
@end

@implementation TouchFinger
@synthesize identity;
@synthesize point;
- (void)dealloc {
    [identity release];
    [super dealloc];
}
@end

@interface CustomWindow : NSWindow {
    NSPoint initialLocation;
}
@property (assign) NSPoint initialLocation;
@end

@interface CustomView : NSView {
    NSImage *ledImage;
	int ledLayer;
	int ledState;
    NSImage *screenImage;
    int screenRotation;
}
@property (retain) NSImage *ledImage;
@property (assign) int ledLayer;
@property (assign) int ledState;
@property (retain) NSImage *screenImage;
@property (assign) int screenRotation;
@end

@interface ScreenView : NSView {
	NSURL *archiveURL;
	NSString *archiveName;
	int archiveFile;
	int archiveSize;
	NSURL *libraryURL;
	NSString *libraryName;
	void* library;
	txScreen* screen;
    NSTimeInterval time;
	NSTimer *timer;
    NSImage *touchImage;
	id *touches;
	BOOL touching;
}
@property (retain) NSString *archiveName;
@property (retain) NSURL *archiveURL;
@property (assign) int archiveFile;
@property (assign) int archiveSize;
@property (retain) NSString *libraryName;
@property (retain) NSURL *libraryURL;
@property (assign) void* library;
@property (assign) txScreen *screen;
@property (assign) NSTimeInterval time;
@property (assign) NSTimer *timer;
@property (retain) NSImage *touchImage;
@property (assign) id *touches;
@property (assign) BOOL touching;
- (void)abortMachine:(NSObject *)object;
- (void)launchMachine;
- (void)quitMachine;
@end

@interface AppDelegate : NSObject <NSApplicationDelegate> {
	ScreenView *screenView;
	NSWindow *window;
	NSURL *libraryURL;
	NSURL *archiveURL;
	NSMutableArray *mockups;
}
@property (retain) ScreenView *screenView;
@property (retain) NSWindow *window;
@property (retain) NSURL *libraryURL;
@property (retain) NSURL *archiveURL;
@property (retain) NSMutableArray *mockups;
@end

static void fxScreenAbort(txScreen* screen, int status);
static void fxScreenBufferChanged(txScreen* screen);
static void fxScreenFormatChanged(txScreen* screen);
static void fxScreenStart(txScreen* screen, double interval);
static void fxScreenStop(txScreen* screen);

@implementation AppDelegate
@synthesize screenView;
@synthesize window;
@synthesize libraryURL;
@synthesize archiveURL;
@synthesize mockups;
- (void)dealloc {
    [mockups release];
    [archiveURL release];
    [libraryURL release];
    [screenView release];
    [window release];
    [super dealloc];
}
- (void) applicationWillFinishLaunching:(NSNotification *)notification {
	NSURL* url = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    libraryURL = [url URLByAppendingPathComponent:@"tech.moddable.simulator.so" isDirectory:NO];
   	archiveURL = [url URLByAppendingPathComponent:@"tech.moddable.simulator.xsa" isDirectory:NO];

	NSMenu* menubar = [[NSMenu new] autorelease];
	NSMenu *servicesMenu = [[NSMenu new] autorelease];
	NSMenuItem* item;

	NSMenu* applicationMenu = [[NSMenu new] autorelease];
	item = [[[NSMenuItem alloc] initWithTitle:@"About Screen Test" action:@selector(about:) keyEquivalent:@""] autorelease];
	[applicationMenu addItem:item];
    [applicationMenu addItem:[NSMenuItem separatorItem]];
	item = [[[NSMenuItem alloc] initWithTitle:@"Touch Mode"  action:@selector(toggleTouchMode:) keyEquivalent:@"t"] autorelease];
	[applicationMenu addItem:item];
    [applicationMenu addItem:[NSMenuItem separatorItem]];
	item = [[[NSMenuItem alloc] initWithTitle:@"Service" action:NULL keyEquivalent:@""] autorelease];
	[item setSubmenu:servicesMenu];
  	[applicationMenu addItem:item];
	item = [[[NSMenuItem alloc] initWithTitle:@"Hide Screen Test" action:@selector(hide:) keyEquivalent:@"h"] autorelease];
  	[applicationMenu addItem:item];
	item = [[[NSMenuItem alloc] initWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"] autorelease];
	[item setKeyEquivalentModifierMask:NSEventModifierFlagOption];
  	[applicationMenu addItem:item];
	item = [[[NSMenuItem alloc] initWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""] autorelease];
  	[applicationMenu addItem:item];
    [applicationMenu addItem:[NSMenuItem separatorItem]];
	item = [[[NSMenuItem alloc] initWithTitle:@"Quit Screen Test"  action:@selector(terminate:) keyEquivalent:@"q"] autorelease];
	[applicationMenu addItem:item];
	item = [[NSMenuItem new] autorelease];
	[item setSubmenu:applicationMenu];
	[menubar addItem:item];
	
	NSMenu* fileMenu = [[[NSMenu alloc] initWithTitle:@"File"] autorelease];
	item = [[[NSMenuItem alloc] initWithTitle:@"Open..." action:@selector(openLibrary:) keyEquivalent:@"o"] autorelease];
	[fileMenu addItem:item];
	item = [[[NSMenuItem alloc] initWithTitle:@"Close" action:@selector(closeLibrary:) keyEquivalent:@"w"] autorelease];
	[fileMenu addItem:item];
    [fileMenu addItem:[NSMenuItem separatorItem]];
	item = [[[NSMenuItem alloc] initWithTitle:@"Get Info"  action:@selector(getInfo:) keyEquivalent:@"i"] autorelease];
	[fileMenu addItem:item];
	item = [[NSMenuItem new] autorelease];
	[item setSubmenu:fileMenu];
	[menubar addItem:item];

	NSArray *paths = [[NSBundle mainBundle] pathsForResourcesOfType:@"json" inDirectory:@"screens"];
    paths = [paths sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSInteger c = [paths count], i;
	mockups = [[NSMutableArray alloc] init];
	for (i = 0; i < c; i++) {
		NSString *path = [paths objectAtIndex:i];
		NSData *data = [[NSData alloc] initWithContentsOfFile:path];
		NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    	NSString* title = [json valueForKeyPath:@"title"];
		item = [[[NSMenuItem alloc] initWithTitle:title action:@selector(selectScreen:) keyEquivalent:@""] autorelease];
        item.representedObject = path;
        item.tag = i;
 		Mockup *mockup = [Mockup alloc];
		mockup.item = item;
   		NSString *name = [[path lastPathComponent] stringByDeletingPathExtension];
		mockup.name = name;
		[mockups addObject:mockup];
	}
	
    NSMenu* screenMenu = [[[NSMenu alloc] initWithTitle:@"Size"] autorelease];
	for (i = 0; i < c; i++) {
 		Mockup *mockup = [mockups objectAtIndex:i];
		[screenMenu addItem:mockup.item];
	}
	item = [[NSMenuItem new] autorelease];
	[item setSubmenu:screenMenu];
	[menubar addItem:item];
	
    NSMenu* rotationMenu = [[[NSMenu alloc] initWithTitle:@"Rotation"] autorelease];
	item = [[[NSMenuItem alloc] initWithTitle:@"0°" action:@selector(selectRotation:) keyEquivalent:@""] autorelease];
    item.tag = 0;
	[rotationMenu addItem:item];
	item = [[[NSMenuItem alloc] initWithTitle:@"90°" action:@selector(selectRotation:) keyEquivalent:@""] autorelease];
    item.tag = 90;
	[rotationMenu addItem:item];
	item = [[[NSMenuItem alloc] initWithTitle:@"180°" action:@selector(selectRotation:) keyEquivalent:@""] autorelease];
    item.tag = 180;
	[rotationMenu addItem:item];
	item = [[[NSMenuItem alloc] initWithTitle:@"270°" action:@selector(selectRotation:) keyEquivalent:@""] autorelease];
    item.tag = 270;
	[rotationMenu addItem:item];
	item = [[NSMenuItem new] autorelease];
	[item setSubmenu:rotationMenu];
	[menubar addItem:item];
	
	NSMenu* helpMenu = [[[NSMenu alloc] initWithTitle:@"Help"] autorelease];
	item = [[[NSMenuItem alloc] initWithTitle:@"Moddable Developer" action:@selector(support:) keyEquivalent:@""] autorelease];
	[helpMenu addItem:item];
	item = [[NSMenuItem new] autorelease];
	[item setSubmenu:helpMenu];
	[menubar addItem:item];
	
	[NSApp setMainMenu:menubar];
	[NSApp setServicesMenu: servicesMenu];
	
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults objectForKey:@"screenTag"]) {
    	i = [userDefaults integerForKey:@"screenTag"];
    }
    else {
    	i = -1;
    }
    if ((i < 0) || (c <= i)) {
    	i = 4;
    	[userDefaults setInteger:i forKey:@"screenTag"];
    }
    item = [screenMenu itemWithTag:i];
    item.state = 1;
    
    if ([userDefaults objectForKey:@"rotation"]) {
    	i = [userDefaults integerForKey:@"rotation"];
    }
    else {
    	i = 0;
    }
    item = [rotationMenu itemWithTag:i];
    item.state = 1;

   [self createScreen];
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self.window makeKeyAndOrderFront:NSApp];
}
- (void)application:(NSApplication *)application openFiles:(NSArray *)filenames
{
	NSInteger c = [filenames count], i;
	NSString* filename;
	NSString* extension;
	NSFileManager* manager = [NSFileManager defaultManager];
	NSError* error = nil;
	if (c) {
		BOOL launch = NO;
		[self.screenView quitMachine];
		for (i = 0; i < c; i++) {
			filename = [filenames objectAtIndex:i];
			extension = [filename pathExtension];
			if ([extension compare:@"so"] == NSOrderedSame) {
				[manager removeItemAtURL:libraryURL error:&error];
				[manager copyItemAtURL:[NSURL fileURLWithPath:filename] toURL:libraryURL error:&error];
				self.screenView.libraryName = filename;
				launch = YES;
			}
			else if ([extension compare:@"xsa"] == NSOrderedSame) {
				[manager removeItemAtURL:archiveURL error:&error];
				[manager copyItemAtURL:[NSURL fileURLWithPath:filename] toURL:archiveURL error:&error];
				self.screenView.archiveName = filename;
				launch = YES;
			}
		}
		if (launch) {
			NSString* path = self.screenView.libraryName;
			NSArray *pathComponents = [path pathComponents];
			NSInteger c = [pathComponents count], i;
			NSString* name = [pathComponents objectAtIndex:c - 4];
			c = [mockups count];
			for (i = 0; i < c; i++) {
				Mockup *mockup = [mockups objectAtIndex:i];
				if ([mockup.name hasSuffix:name]) {
					NSMenuItem* item = mockup.item;
					if (item.state)
						[self.screenView launchMachine];
					else
						[self selectScreen:item];
					return;
				}
			}
			[self.screenView launchMachine];
		}
	}
}
- (void)about:(NSMenuItem *)sender {
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setAlertStyle:NSAlertStyleInformational];
	[alert setMessageText:@"Screen Test"];
	[alert setInformativeText:@"Copyright 2017-2022 Moddable Tech, Inc.\nAll rights reserved.\n\nThis application incorporates open source software from Marvell, Inc. and others."];
	[alert beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
		[alert.window close]; 
	}];
}
- (void)closeLibrary:(NSMenuItem *)sender {
	[self.screenView quitMachine];
    self.screenView.archiveName = nil;
    self.screenView.libraryName = nil;
}
- (void)createScreen {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSInteger index = [userDefaults integerForKey:@"screenTag"];
    NSInteger rotation = [userDefaults integerForKey:@"rotation"];
    Mockup* mockup = mockups[index];
    NSString *jsonPath = mockup.item.representedObject;
    NSString *screenImagePath = [[jsonPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"];
    NSImage *screenImage = [[NSImage alloc] initByReferencingFile:screenImagePath];
    NSSize size = [screenImage size];
    NSData *data = [[NSData alloc] initWithContentsOfFile:jsonPath];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    NSInteger x = [[json valueForKeyPath:@"x"] integerValue];
    NSInteger y = [[json valueForKeyPath:@"y"] integerValue];
    NSInteger width = [[json valueForKeyPath:@"width"] integerValue];
    NSInteger height = [[json valueForKeyPath:@"height"] integerValue];
    NSInteger led = [[json valueForKeyPath:@"led"] integerValue];
   	NSRect customRect, screenRect;
   	switch (rotation) {
   	case 0:
 		customRect = NSMakeRect(0, 0, size.width, size.height);
		screenRect = NSMakeRect(x, size.height - (y + height), width, height);
   		break;
   	case 90:
 		customRect = NSMakeRect(0, 0, size.height, size.width);
		screenRect = NSMakeRect(y, x, height, width);
   		break;
   	case 180:
 		customRect = NSMakeRect(0, 0, size.width, size.height);
		screenRect = NSMakeRect(size.width - (x + width), y, width, height);
   		break;
   	case 270:
 		customRect = NSMakeRect(0, 0, size.height, size.width);
		screenRect = NSMakeRect(size.height - (y + height), size.width - (x + width), height, width);
   		break;
   	}
    CustomWindow* customWindow = [[CustomWindow alloc] initWithContentRect:customRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
    CustomView *customView = [[[CustomView alloc] initWithFrame:customRect] autorelease];
    customView.screenRotation = rotation;
    ScreenView *_screenView = [[[ScreenView alloc] initWithFrame:screenRect] autorelease];
    _screenView.boundsRotation = rotation;
   
    _screenView.archiveURL = archiveURL;
    _screenView.archiveName = nil;
    _screenView.archiveFile = -1;
    _screenView.archiveSize = 0;
    _screenView.libraryURL = libraryURL;
    _screenView.libraryName = nil;
    _screenView.library = NULL;
    
    txScreen* screen = malloc(sizeof(txScreen) - 1 + (width * height * screenBytesPerPixel));
    memset(screen, 0, sizeof(txScreen) - 1 + (width * height * screenBytesPerPixel));
    screen->archive = NULL;
    screen->view = _screenView;
    screen->abort = fxScreenAbort;
    screen->bufferChanged = fxScreenBufferChanged;
    screen->formatChanged = fxScreenFormatChanged;
    screen->start = fxScreenStart;
    screen->stop = fxScreenStop;
    screen->width = width;
    screen->height = height;
    _screenView.screen = screen;
    
    NSProcessInfo* processInfo = [NSProcessInfo processInfo];
    NSTimeInterval time = [processInfo systemUptime];
    NSDate* date = [NSDate dateWithTimeIntervalSinceNow:-time];
    _screenView.time = [date timeIntervalSince1970];
    _screenView.timer = nil;
  
    _screenView.touchImage = [NSImage imageNamed:@"fingerprint"];
	_screenView.touches = (id *)malloc(10 * sizeof(id));
    int i;
    for (i = 0; i < 10; i++)
		_screenView.touches[i] = nil;
	 _screenView.touching = NO;
	 
	if (led) {
    	NSString *ledImagePath = [[jsonPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"led.png"];
 		customView.ledImage = [[NSImage alloc] initByReferencingFile:ledImagePath];
	}
	else
		customView.ledImage = nil;
    customView.ledLayer = led;
  	customView.ledState = 0;
   	customView.screenImage = screenImage;
    [customView addSubview:_screenView];
    [customWindow setContentView:customView];
    [customWindow setAlphaValue:1.0];
    [customWindow setOpaque:NO];
    [customWindow setBackgroundColor: [NSColor clearColor]];
    if (![customWindow setFrameUsingName:@"screen"])
        [customWindow cascadeTopLeftFromPoint:NSMakePoint(20, 20)];
    [customWindow registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,nil]];
	self.screenView = _screenView;
    self.window = customWindow;
}
- (void)deleteScreen {
    [self.window close];
}
- (void)getInfo:(NSMenuItem *)sender {
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setAlertStyle:NSAlertStyleInformational];
	if (screenView.archiveName)
		[alert setMessageText:[NSString stringWithFormat:@"%@ - %@",[[screenView.libraryName stringByDeletingLastPathComponent] lastPathComponent],[[screenView.archiveName stringByDeletingLastPathComponent] lastPathComponent]]];
	else
		[alert setMessageText:[[screenView.libraryName stringByDeletingLastPathComponent] lastPathComponent]];
	[alert setInformativeText:gPixelFormatNames[screenView.screen->pixelFormat]];
	[alert beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
		[alert.window close]; 
	}];
}
- (void)openLibrary:(NSMenuItem *)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowedFileTypes: [NSArray arrayWithObjects:@"so", @"xsa", nil]];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setCanChooseFiles:YES];
	[openPanel beginSheetModalForWindow:[NSApp mainWindow] completionHandler:^(NSInteger result) {		
		NSArray *urls = [openPanel URLs];
		NSMutableArray *filenames = [NSMutableArray arrayWithCapacity:[urls count]];
		[urls enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			[filenames addObject:[obj path]];
		}];	
    	[self application:[NSApplication sharedApplication] openFiles:filenames];
	}];
}
- (void)selectRotation:(NSMenuItem *)sender {
    if (sender.state)
        return;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSInteger rotation = [userDefaults integerForKey:@"rotation"];
    NSMenu *menu = [sender menu];
    NSMenuItem *current = [menu itemWithTag:rotation];
    current.state = 0;
    sender.state = 1;
    [userDefaults setInteger:sender.tag forKey:@"rotation"];
    
    NSString* archiveName = self.screenView.archiveName;
    NSString* libraryName = self.screenView.libraryName;
	[self.screenView quitMachine];
    [self deleteScreen];
    [self createScreen];
    self.screenView.archiveName = archiveName;
    self.screenView.libraryName = libraryName;
	[self.screenView launchMachine];
    [self.window makeKeyAndOrderFront:NSApp];
}
- (void)selectScreen:(NSMenuItem *)sender {
    if (sender.state)
        return;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSInteger screenTag = [userDefaults integerForKey:@"screenTag"];
    NSMenu *menu = [sender menu];
    NSMenuItem *current = [menu itemWithTag:screenTag];
    current.state = 0;
    sender.state = 1;
    [userDefaults setInteger:sender.tag forKey:@"screenTag"];
    
    NSString* archiveName = self.screenView.archiveName;
    NSString* libraryName = self.screenView.libraryName;
	[self.screenView quitMachine];
    [self deleteScreen];
    [self createScreen];
    self.screenView.archiveName = archiveName;
    self.screenView.libraryName = libraryName;
	[self.screenView launchMachine];
    [self.window makeKeyAndOrderFront:NSApp];
}
- (void)support:(NSMenuItem *)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://moddable.tech"]];
}
- (void)toggleTouchMode:(NSMenuItem *)sender {
    if (sender.state) {
		CGAssociateMouseAndMouseCursorPosition(true);
		CGDisplayShowCursor(kCGDirectMainDisplay);
    	screenView.touching = NO;
    	[screenView setAcceptsTouchEvents:NO];
    	screenView.wantsRestingTouches = NO;
    	sender.state = 0;
    }
    else {
		NSRect frame = [window frame];
		CGPoint point;
		point.x = frame.origin.x + (frame.size.width / 2);
		point.y = [[window screen] frame].size.height - (frame.origin.y + (frame.size.height / 2));
		CGAssociateMouseAndMouseCursorPosition(false);
		CGDisplayMoveCursorToPoint(kCGDirectMainDisplay, point);
		CGDisplayHideCursor(kCGDirectMainDisplay);
    	screenView.touching = YES;
    	[screenView setAcceptsTouchEvents:YES];
        screenView.wantsRestingTouches = YES;
     	sender.state = 1;
    }
}
- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if ((item.action == @selector(closeLibrary:)) || (item.action == @selector(getInfo:))) {
		return (screenView.library) ? YES : NO;
    }
    return YES;
}
@end

@implementation CustomWindow
@synthesize initialLocation;
- (BOOL)canBecomeKeyWindow {
    return YES;
}
- (void)mouseDown:(NSEvent *)theEvent {
    self.initialLocation = [theEvent locationInWindow];
}
- (void)mouseDragged:(NSEvent *)theEvent {
    NSRect windowFrame = [self frame];
    NSPoint newOrigin = windowFrame.origin;
    NSPoint currentLocation = [theEvent locationInWindow];
    newOrigin.x += (currentLocation.x - initialLocation.x);
    newOrigin.y += (currentLocation.y - initialLocation.y);
    [self setFrameOrigin:newOrigin];
}
- (void)mouseUp:(NSEvent *)theEvent {
	[self saveFrameUsingName:@"screen"];
}
- (NSDragOperation)draggingEntered:(id )sender
{
    return NSDragOperationGeneric;
}
- (NSDragOperation)draggingUpdated:(id )sender
{
    return NSDragOperationGeneric;
}
- (BOOL)prepareForDragOperation:(id )sender
{
    return YES;
}
- (BOOL)performDragOperation:(id )sender {
	NSPasteboard *pasteboard = [sender draggingPasteboard];
	NSArray *filenames = [pasteboard propertyListForType:@"NSFilenamesPboardType"];
	NSApplication* application = [NSApplication sharedApplication];
    [[application delegate] application:application openFiles:filenames];
	return YES;
}
- (void)concludeDragOperation:(id )sender
{
}
@end

@implementation CustomView
@synthesize ledImage;
@synthesize ledLayer;
@synthesize ledState;
@synthesize screenImage;
@synthesize screenRotation;
- (void)dealloc {
	[screenImage release];
	[ledImage release];
    [super dealloc];
}
- (void)drawRect:(NSRect)rect {
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
 	NSAffineTransform *rotate = [[NSAffineTransform alloc] init];
    NSSize size = [screenImage size];
	[context saveGraphicsState];
    [rotate rotateByDegrees:screenRotation];
	[rotate concat];
	NSPoint at;
	switch (screenRotation) {
	case 0: at = NSMakePoint(0, 0); break;
	case 90: at = NSMakePoint(0, -size.height); break;
	case 180: at = NSMakePoint(-size.width, -size.height); break;
	case 270: at = NSMakePoint(-size.width, 0); break;
	}
    if (ledState && (ledLayer < 0))
    	[ledImage drawAtPoint:at fromRect:NSMakeRect(0, 0, 0, 0) operation:NSCompositeSourceOver fraction:1.0];
    [screenImage drawAtPoint:at fromRect:NSMakeRect(0, 0, 0, 0) operation:NSCompositeSourceOver fraction:1.0];
    if (ledState && (ledLayer > 0))
    	[ledImage drawAtPoint:at fromRect:NSMakeRect(0, 0, 0, 0) operation:NSCompositeSourceOver fraction:1.0];
	[rotate release];
	[context restoreGraphicsState];
}
@end

@implementation ScreenView
@synthesize archiveURL;
@synthesize archiveName;
@synthesize archiveFile;
@synthesize archiveSize;
@synthesize libraryURL;
@synthesize libraryName;
@synthesize library;
@synthesize screen;
@synthesize time;
@synthesize timer;
@synthesize touchImage;
@synthesize touches;
@synthesize touching;
- (BOOL)acceptsFirstResponder {
    return YES;
}
- (void)dealloc {
	if (screen)
    	free(screen);
	if (library)
    	dlclose(library);
    [libraryName release];
    [archiveName release];
    [touchImage release];
    [super dealloc];
}
- (void)abortMachine:(NSObject *)object {
    [self quitMachine];
	NSData* data = (NSData*)object;
	int status;
	[data getBytes:&status length: sizeof(status)];
    if (status) {
		char* reasons[9] = {
			"",
			"memory full",
			"stack overflow",
			"fatal check",
			"dead strip",
			"unhandled exception",
			"not enough keys",
			"too much computation",
			"unhandled rejection",
		};
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setAlertStyle:NSAlertStyleCritical];
		[alert setMessageText:@"Screen Test"];
		[alert setInformativeText:[NSString stringWithFormat:@"XS abort: %s!",reasons[status]]];
		[alert beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
			[alert.window close]; 
		}];
	}
}
- (void)drawRect:(NSRect)rect {
	CGRect bounds = NSRectToCGRect(self.bounds);
	CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGDataProviderRef provider = CGDataProviderCreateWithData(nil, screen->buffer, screen->width * screen->height * screenBytesPerPixel, nil);
    CGImageRef image = CGImageCreate(screen->width, screen->height, 8, 32, screen->width * screenBytesPerPixel, colorSpace, kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipLast, provider, nil, NO, kCGRenderingIntentDefault);
	CGContextDrawImage(context, bounds, image);
	CGImageRelease(image);
	CGDataProviderRelease(provider);
	CGColorSpaceRelease(colorSpace);
	if (touching) {
		int i;
		for (i = 0; i < 10;  i++) {
			TouchFinger *finger = touches[i];
			if (finger) {
				[touchImage drawAtPoint:finger.point fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
			}
		}
	}
}
- (void)keyDown:(NSEvent *)event {
	NSString* string = [event charactersIgnoringModifiers];
	NSEventModifierFlags flags = [event modifierFlags];
	NSTimeInterval when = 1000 * (time + [event timestamp]);
	int modifiers = 0;
	if ([event isARepeat]) modifiers |= keyEventRepeat;
	if (flags & NSEventModifierFlagCommand) modifiers |= keyEventCommand;
	if (flags & NSEventModifierFlagOption) modifiers |= keyEventOption;
	if (flags & NSEventModifierFlagShift) modifiers |= keyEventShift;
	if (self.screen->key) 
		(*self.screen->key)(self.screen, keyEventDown, (char*)[string UTF8String], modifiers, when);
}
- (void)keyUp:(NSEvent *)event {
	NSString* string = [event charactersIgnoringModifiers];
	NSEventModifierFlags flags = [event modifierFlags];
	NSTimeInterval when = 1000 * (time + [event timestamp]);
	int modifiers = 0;
	if (flags & NSEventModifierFlagCommand) modifiers |= keyEventCommand;
	if (flags & NSEventModifierFlagOption) modifiers |= keyEventOption;
	if (flags & NSEventModifierFlagShift) modifiers |= keyEventShift;
	if (self.screen->key) 
		(*self.screen->key)(self.screen, keyEventUp, (char*)[string UTF8String], modifiers, when);
}
- (void)launchMachine {
	NSString *name = nil;
	NSString *info = nil;
	txScreenLaunchProc launch;
	if (self.libraryName) {
		self.library = dlopen([self.libraryURL fileSystemRepresentation], RTLD_NOW);
		if (!self.library) {
			name = self.libraryName;
			info = [NSString stringWithFormat:@"%s", dlerror()];
			goto bail;
		}
		launch = (txScreenLaunchProc)dlsym(self.library, "fxScreenLaunch");
		if (!launch) {
			name = self.libraryName;
			info = [NSString stringWithFormat:@"%s", dlerror()];
			goto bail;
		}
	
		if (self.archiveName) {
			struct stat statbuf;
			self.archiveFile = open([self.archiveURL fileSystemRepresentation], O_RDWR);
			if (self.archiveFile < 0) {
				name = self.archiveName;
				info = [NSString stringWithFormat:@"%s", strerror(errno)];
				goto bail;
			}
			fstat(self.archiveFile, &statbuf);
			self.archiveSize = statbuf.st_size;
			self.screen->archive = mmap(NULL, self.archiveSize, PROT_READ|PROT_WRITE, MAP_SHARED, self.archiveFile, 0);
			if (self.screen->archive == MAP_FAILED) {
				self.screen->archive = NULL;
				name = self.archiveName;
				info = [NSString stringWithFormat:@"%s", strerror(errno)];
				goto bail;
			}
		}

		(*launch)(self.screen);
	}
	return;
bail:
	if (self.screen->archive) {
		munmap(self.screen->archive, self.archiveSize);
		self.screen->archive = NULL;
		self.archiveSize = 0;
	}
	if (self.archiveFile >= 0) {
		close(self.archiveFile);
		self.archiveFile = -1;
	}
	if (self.library) {
		dlclose(self.library);
		self.library = nil;
	}
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:[NSString stringWithFormat:@"Cannot open \"%@\"", name]];
	if (info)
		[alert setInformativeText:info];
	[alert runModal];
}
- (NSPoint)rotatePoint:(NSPoint)point {
	NSSize size = [self bounds].size;
    NSPoint result;
    switch ((int)(self.boundsRotation)) {
    case 0:
    	result.x = point.x;
		result.y = size.height - point.y;
		break;
    case 90:
    	result.x = point.x;
		result.y = 0 - point.y;
		break;
    case 180:
    	result.x = size.width + point.x;
		result.y = 0 - point.y;
		break;
    case 270:
    	result.x = size.width + point.x;
        result.y = size.height - point.y;
		break;
    }
    return result;
}
- (void)mouseDown:(NSEvent *)event {
	if (touching)
		return;
	NSTimeInterval when = 1000 * (time + [event timestamp]);
	NSPoint point = [event locationInWindow];
	point = [self convertPoint:point fromView:nil];
	point = [self rotatePoint:point];
	if (self.screen->touch) 
		(*self.screen->touch)(self.screen, touchEventBeganKind, 0, point.x, point.y, when);
}
- (void)mouseDragged:(NSEvent *)event {
	if (touching)
		return;
	NSTimeInterval when = 1000 * (time + [event timestamp]);
	NSPoint point = [event locationInWindow];
	point = [self convertPoint:point fromView:nil];
	point = [self rotatePoint:point];
	if (self.screen->touch) 
		(*self.screen->touch)(self.screen, touchEventMovedKind, 0, point.x, point.y, when);
}
- (void)mouseUp:(NSEvent *)event {
	if (touching)
		return;
	NSTimeInterval when = 1000 * (time + [event timestamp]);
	NSPoint point = [event locationInWindow];
	point = [self convertPoint:point fromView:nil];
	point = [self rotatePoint:point];
	if (self.screen->touch) 
		(*self.screen->touch)(self.screen, touchEventEndedKind, 0, point.x, point.y, when);
}
- (void)quitMachine {
	if (self.screen->quit) 
		(*self.screen->quit)(self.screen);
	if (self.screen->archive) {
		munmap(self.screen->archive, self.archiveSize);
		self.screen->archive = NULL;
		self.archiveSize = 0;
	}
	if (self.archiveFile >= 0) {
		close(self.archiveFile);
		self.archiveFile = -1;
	}
	if (self.library) {
    	dlclose(self.library);
    	self.library = nil;
    }
    [self display];
}
- (void)timerCallback:(NSTimer*)theTimer {
	if (self.screen->idle) 
		(*self.screen->idle)(self.screen);
}
- (void)touchesBeganWithEvent:(NSEvent *)event {
	if (!touching)
		return;
    NSSet *set = [event touchesMatchingPhase:NSTouchPhaseBegan inView:nil];
    NSEnumerator *enumerator = [set objectEnumerator];
    NSTouch* touch;
    int i;
	NSSize size = [self frame].size;
	NSTimeInterval when = 1000 * (time + [event timestamp]);
	while ((touch = [enumerator nextObject])) {
		NSPoint point = touch.normalizedPosition;
		point.x *= size.width;
		point.y *= size.height;
		for (i = 0; i < 10;  i++) {
			if (touches[i] == nil) {
				TouchFinger *finger = [TouchFinger alloc];
				finger.identity = touch.identity;
				finger.point = point;
    			touches[i] = [finger retain];
  				break;
			}
		}
		point = [self rotatePoint:point];
		if (self.screen->touch) 
			(*self.screen->touch)(self.screen, touchEventBeganKind, i, point.x, point.y, when);
	}  
}
- (void)touchesCancelledWithEvent:(NSEvent *)event {
	if (!touching)
		return;
    NSSet *set = [event touchesMatchingPhase:NSTouchPhaseCancelled inView:nil];
    NSEnumerator *enumerator = [set objectEnumerator];
    NSTouch* touch;
    int i;
	NSSize size = [self frame].size;
	NSTimeInterval when = 1000 * (time + [event timestamp]);
	while ((touch = [enumerator nextObject])) {
		NSPoint point = touch.normalizedPosition;
		point.x *= size.width;
		point.y *= size.height;
		for (i = 0; i < 10;  i++) {
			TouchFinger *finger = touches[i];
    		if (finger && ([finger.identity isEqual:touch.identity])) {
    			[finger release];
				touches[i] = nil;
   				break;
			}
		}
		point = [self rotatePoint:point];
		if (self.screen->touch) 
			(*self.screen->touch)(self.screen, touchEventCancelledKind, i, point.x, point.y, when);
	}
}
- (void)touchesEndedWithEvent:(NSEvent *)event {
	if (!touching)
		return;
    NSSet *set = [event touchesMatchingPhase:NSTouchPhaseEnded inView:nil];
    NSEnumerator *enumerator = [set objectEnumerator];
    NSTouch* touch;
    int i;
	NSSize size = [self frame].size;
	NSTimeInterval when = 1000 * (time + [event timestamp]);
	while ((touch = [enumerator nextObject])) {
		NSPoint point = touch.normalizedPosition;
		point.x *= size.width;
		point.y *= size.height;
		for (i = 0; i < 10;  i++) {
			TouchFinger *finger = touches[i];
    		if (finger && ([finger.identity isEqual:touch.identity])) {
    			[finger release];
				touches[i] = nil;
    			break;
			}
		}
		point = [self rotatePoint:point];
		if (self.screen->touch) 
			(*self.screen->touch)(self.screen, touchEventEndedKind, i, point.x, point.y, when);
	}
}
- (void)touchesMovedWithEvent:(NSEvent *)event {
	if (!touching)
		return;
    NSSet *set = [event touchesMatchingPhase:NSTouchPhaseMoved inView:nil];
    NSEnumerator *enumerator = [set objectEnumerator];
    NSTouch* touch;
    int i;
	NSSize size = [self frame].size;
	NSTimeInterval when = 1000 * (time + [event timestamp]);
	while ((touch = [enumerator nextObject])) {
		NSPoint point = touch.normalizedPosition;
		point.x *= size.width;
		point.y *= size.height;
		for (i = 0; i < 10;  i++) {
			TouchFinger *finger = touches[i];
    		if (finger && ([finger.identity isEqual:touch.identity])) {
				finger.point = point;
   				break;
			}
		}
		point = [self rotatePoint:point];
		if (self.screen->touch) 
			(*self.screen->touch)(self.screen, touchEventMovedKind, i, point.x, point.y, when);
	}
}
@end

void fxScreenAbort(txScreen* screen, int status)
{
	ScreenView *screenView = screen->view;
	NSData* data = [NSData dataWithBytes:&status length:sizeof(status)];
    [screenView performSelectorOnMainThread:@selector(abortMachine:) withObject:data waitUntilDone:NO];
}

void fxScreenBufferChanged(txScreen* screen)
{
	ScreenView *screenView = screen->view;
	[screenView display];
}

void fxScreenFormatChanged(txScreen* screen)
{
	ScreenView *screenView = screen->view;
	CustomView *customView = (CustomView *)screenView.superview;
	customView.ledState = (screen->flags & mxScreenLED) ? 1 :  0;
	customView.needsDisplay = YES;
}

void fxScreenStart(txScreen* screen, double interval)
{
	ScreenView *screenView = screen->view;
	screenView.timer = [NSTimer scheduledTimerWithTimeInterval:interval/1000 target:screenView selector:@selector(timerCallback:) userInfo:nil repeats:YES];
}

void fxScreenStop(txScreen* screen)
{
	ScreenView *screenView = screen->view;
	if (screenView.timer)
		[screenView.timer invalidate];
	screenView.timer = nil;
}

int main(int argc, const char **argv)
{
	[NSApplication sharedApplication];
	[NSApp setDelegate: [AppDelegate new]];
	return NSApplicationMain(argc, argv);
}
