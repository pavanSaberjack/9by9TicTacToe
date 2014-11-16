//
//  BoardBaseView.m
//  9By9TicTacToe
//
//  Created by Pavan Itagi on 16/11/14.
//  Copyright (c) 2014 Pavan Itagi. All rights reserved.
//

#import "BoardBaseView.h"

static NSString *cellIdentifier = @"cellIdentifier";

@interface BoardBaseView()<UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, weak) UICollectionView *baseCollectionView;
@end

@implementation BoardBaseView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/
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

#pragma mark - UI creation methods
- (void)setUpUI
{
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    [flowLayout setItemSize:CGSizeMake(25, 25)];
    [flowLayout setSectionInset:UIEdgeInsetsMake(2, 2, 2, 2)];
    
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:self.bounds collectionViewLayout:flowLayout];
    [collectionView setBackgroundColor:[UIColor whiteColor]];
    collectionView.delegate = self;
    collectionView.dataSource = self;
    [collectionView setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
    [collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:cellIdentifier];
    
    [self addSubview:collectionView];
    self.baseCollectionView = collectionView;
    [self.baseCollectionView reloadData];
    
}

#pragma mark - UICollectionViewDataSource methods
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 9; // 9 blocks total
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    [cell.contentView setBackgroundColor:[UIColor grayColor]];
    
    return cell;
}

#pragma mark - UICollectionViewDelegate methods
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.delegate respondsToSelector:@selector(boardBaseView:didClickedAtIndexPath:)])
    {
        [self.delegate boardBaseView:self didClickedAtIndexPath:indexPath];
    }
}
@end
