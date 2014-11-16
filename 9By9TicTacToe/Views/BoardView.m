//
//  BoardView.m
//  9By9TicTacToe
//
//  Created by Pavan Itagi on 16/11/14.
//  Copyright (c) 2014 Pavan Itagi. All rights reserved.
//

#import "BoardView.h"
#import "BoardBaseView.h"

static NSString *cellIdentifier = @"cellIdentifier";

@interface BoardView() <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, BoardBaseViewDelegate>
@property (nonatomic, weak) UICollectionView *mainCollectionView;
@end

@implementation BoardView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setUpUI];
    }
    
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [self setUpUI];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

#pragma mark - UI creation methods
- (void)setUpUI
{
    CGFloat itemWidth = (CGRectGetWidth(self.bounds) - 20)/3.0;
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    [flowLayout setItemSize:CGSizeMake(itemWidth, itemWidth)];
    [flowLayout setSectionInset:UIEdgeInsetsMake(100, 20, 50, 20)];
    
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:self.bounds collectionViewLayout:flowLayout];
    [collectionView setBackgroundColor:[UIColor whiteColor]];
    collectionView.delegate = self;
    collectionView.dataSource = self;
    [collectionView setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
    [collectionView setScrollEnabled:NO];
    [collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:cellIdentifier];
    
    [self addSubview:collectionView];
    self.mainCollectionView = collectionView;
    [self.mainCollectionView reloadData];
    
}

#pragma mark - UICollectionViewDataSource methods
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 9; // 9 blocks total
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    [cell.contentView setBackgroundColor:[UIColor blackColor]];
    BoardBaseView *baseView = [[BoardBaseView alloc] initWithFrame:cell.bounds];
    [baseView setIndexPath:indexPath];
    [baseView setDelegate:self];
    [cell.contentView addSubview:baseView];
    return cell;
}

#pragma mark - UICollectionViewDelegate methods
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    
}

#pragma mark - BoardBaseViewDelegate methods
- (void)boardBaseView:(BoardBaseView *)baseView didClickedAtIndexPath:(NSIndexPath *)indexPath
{
    //
    
    UICollectionViewCell *cell = [self.mainCollectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:2 inSection:0]];
    [cell setAlpha:0.1];
}
@end
