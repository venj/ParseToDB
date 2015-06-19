//
//  Controller.m
//  
//
//  Created by 朱 文杰 on 15/6/19.
//
//

#import "Controller.h"
#include <iostream>
#include <fstream>
#import <FMDB/FMDB.h>

using namespace std;

@interface Controller()
@property (weak) IBOutlet NSTextField *pathField;
@property (weak) IBOutlet NSProgressIndicator *progressBar;
@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) NSURL *textURL;
@property (weak) IBOutlet NSButton *startButton;
@property (weak) IBOutlet NSProgressIndicator *spinner;
@end

@implementation Controller

- (IBAction)openFile:(id)sender {
    __weak typeof(self) weakself = self;
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.canChooseFiles = YES;
    openPanel.canCreateDirectories = NO;
    openPanel.resolvesAliases = YES;
    openPanel.allowsMultipleSelection = NO;
    openPanel.allowedFileTypes = @[@"txt"];
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            weakself.textURL = [openPanel.URL filePathURL];
            weakself.pathField.stringValue = [[openPanel.URL filePathURL] absoluteString];
        }

    }];
}

- (IBAction)startParse:(id)sender {
    [self.startButton setEnabled:NO];
    [self.spinner startAnimation:nil];
    [self parseFile];
}

- (void)parseFile {
    __weak typeof(self)weakself = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        ifstream inf([[self.textURL filePathURL] fileSystemRepresentation]);
        if(!inf) { NSLog(@"Cannot open input file.\n"); }
        
        NSInteger total = 0;
        char str[3072];
        while(inf) { inf.getline(str, 3072); if(inf) { total++; } } inf.clear(); inf.seekg(0); // Count total lines.
        NSString *queryString = @"INSERT INTO torrents (name, magnet, link, genre, torrent, size, category_id, file_count, seeders, leechers, upload_date) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        NSInteger progress = 0;
        
        FMDatabase *db = [FMDatabase databaseWithPath:@"/Users/venj/Desktop/data.db"];
        if (![db open]) {
            NSLog(@"Failed to open database.");
            return;
        }
        
        NSDateComponents *dcomp = [[NSDateComponents alloc] init];
        dcomp.year = 2014; dcomp.month = 1, dcomp.day = 1;
        NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        calendar.locale = [NSLocale localeWithLocaleIdentifier:@"en_GB"];
        NSDate *date2014 = [calendar dateFromComponents:dcomp];
        NSTimeInterval ti2014 = [date2014 timeIntervalSince1970];
        
        NSInteger skipped = 0;
        while(inf) {
            @autoreleasepool {
                inf.getline(str, 3072);
                if(inf) {
                    NSString *line = [[NSString alloc] initWithCString:str encoding:NSUTF8StringEncoding];
                    NSArray *parts = [line componentsSeparatedByString:@"|"];
                    NSTimeInterval ti = [[parts lastObject] integerValue];
                    NSDate *date = [NSDate dateWithTimeIntervalSince1970:ti];
                    if (ti2014 > ti) {
                        skipped++;
                    }
                    else {
                        BOOL result = [db executeUpdate:queryString withArgumentsInArray:
                                       @[parts[1], //name
                                         [NSString stringWithFormat:@"magnet:?xt=urn:btih%@", parts[0]], //magnet
                                         parts[3], //link
                                         parts[2], //genre
                                         parts[4], //torrent
                                         @([parts[5] integerValue]), //size
                                         @([parts[6] integerValue]), //category_id
                                         @([parts[7] integerValue]), //file_count
                                         @([parts[8] integerValue]), //seeders
                                         @([parts[9] integerValue]), //leechers
                                         date //upload_date
                                         ]];
                        
                        if (!result) { NSLog(@"%@", line); }
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        weakself.progressBar.doubleValue = progress / (total * 100.0);
                    });
                    progress++;
                }
            }
        }
        
        [db close];
        inf.close();
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakself.spinner stopAnimation:nil];
            [weakself.startButton setEnabled:YES];
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Info";
            alert.informativeText = [[NSString alloc] initWithFormat:@"Torrents are parsed into sqlite database. Skipped: %ld", skipped];
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
        });
    });
}


@end
