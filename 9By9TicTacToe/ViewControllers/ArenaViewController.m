//
//  ArenaViewController.m
//  9By9TicTacToe
//
//  Created by Pavan Itagi on 16/11/14.
//  Copyright (c) 2014 Pavan Itagi. All rights reserved.
//

#import "ArenaViewController.h"
#import "BoardView.h"

@interface ArenaViewController ()
@property (nonatomic, weak) IBOutlet BoardView *mainArenaView;
@end

@implementation ArenaViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - UI creation methods
- (void)setupUI
{
    
}

@end
