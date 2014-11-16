//
//  ViewController.m
//  9By9TicTacToe
//
//  Created by Pavan Itagi on 13/11/14.
//  Copyright (c) 2014 Pavan Itagi. All rights reserved.
//

#import "ViewController.h"
#import "ArenaViewController.h"

@interface ViewController ()
@property (nonatomic, weak) IBOutlet UILabel *staticLabel;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Button action mathods
- (IBAction)startPlaying:(id)sender
{
    ArenaViewController *arenaVC = [[ArenaViewController alloc] initWithNibName:@"ArenaViewController" bundle:nil];
    [self.navigationController pushViewController:arenaVC animated:YES];
}
@end
