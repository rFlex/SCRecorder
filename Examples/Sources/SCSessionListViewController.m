//
//  SCSessionListViewController.m
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 14/08/14.
//
//

#import "SCSessionListViewController.h"
#import "SCRecordSessionManager.h"
#import "SCSessionTableViewCell.h"

@interface SCSessionListViewController ()

@end

@implementation SCSessionListViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Save current" style:UIBarButtonItemStyleBordered target:self action:@selector(saveCurrentRecordSession)];
    // Do any additional setup after loading the view.
}

- (void)saveCurrentRecordSession {
    [[SCRecordSessionManager sharedInstance] saveRecordSession:_recorder.recordSession];
    [self.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[SCRecordSessionManager sharedInstance] saveRecordSession:_recorder.recordSession];
    NSDictionary *recordSessionMetadata = [[SCRecordSessionManager sharedInstance].savedRecordSessions objectAtIndex:indexPath.row];
    
    SCRecordSession *newRecordSession = [SCRecordSession recordSession:recordSessionMetadata];
    _recorder.recordSession = newRecordSession;
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SCSessionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Session"];
    NSDictionary *recordSession = [[SCRecordSessionManager sharedInstance].savedRecordSessions objectAtIndex:indexPath.row];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"dd/MM/yyyy hh:mm"];
    
    cell.dateLabel.text = [formatter stringFromDate:recordSession[SCRecordSessionDateKey]];
    
    NSArray *recordSegments = recordSession[SCRecordSessionSegmentFilenamesKey];

    cell.segmentsCountLabel.text = [NSString stringWithFormat:@"%d segments", (int)[recordSegments count]];
    
    cell.durationLabel.text = [NSString stringWithFormat:@"%fs", [recordSession[SCRecordSessionDurationKey] doubleValue]];
    
    if (recordSegments.count > 0) {
        NSString *filename = recordSegments.firstObject;
        NSString *directory = recordSession[SCRecordSessionDirectoryKey];
        NSURL *url = [SCRecordSession recordSegmentURLForFilename:filename andDirectory:directory];
        
        [cell.videoPlayerView.player setItemByUrl:url];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *recordSession = [[SCRecordSessionManager sharedInstance].savedRecordSessions objectAtIndex:indexPath.row];
    
    NSArray *urls = recordSession[SCRecordSessionSegmentFilenamesKey];
    NSFileManager *manager = [NSFileManager defaultManager];
    
    for (NSString *path in urls) {
        [manager removeItemAtPath:path error:nil];
    }
    
    [[SCRecordSessionManager sharedInstance] removeRecordSessionAtIndex:indexPath.row];
    
    if ([_recorder.recordSession.identifier isEqualToString:[recordSession objectForKey:SCRecordSessionIdentifierKey]]) {
        _recorder.recordSession = nil;
    }
    
    [tableView beginUpdates];
    
    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    
    [tableView endUpdates];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [SCRecordSessionManager sharedInstance].savedRecordSessions.count;
}

@end
