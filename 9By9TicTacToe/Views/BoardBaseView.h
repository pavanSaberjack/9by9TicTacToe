//
//  BoardBaseView.h
//  9By9TicTacToe
//
//  Created by Pavan Itagi on 16/11/14.
//  Copyright (c) 2014 Pavan Itagi. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol BoardBaseViewDelegate;
@interface BoardBaseView : UIView
@property (nonatomic, strong) NSIndexPath *indexPath;
@property (nonatomic, weak) id <BoardBaseViewDelegate>delegate;
@end

@protocol BoardBaseViewDelegate <NSObject>
- (void) boardBaseView:(BoardBaseView *)baseView didClickedAtIndexPath:(NSIndexPath *)indexPath;
@end
