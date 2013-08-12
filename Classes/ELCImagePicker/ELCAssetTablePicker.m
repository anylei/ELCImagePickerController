//
//  AssetTablePicker.m
//
//  Created by ELC on 2/15/11.
//  Copyright 2011 ELC Technologies. All rights reserved.
//

#import "ELCAssetTablePicker.h"
#import "ELCAssetCell.h"
#import "ELCAsset.h"
#import "ELCAlbumPickerController.h"

@interface ELCAssetTablePicker () {
    NSInteger selectedCount; /** Count of selected images */
}

@property (nonatomic, assign) int columns;

@end

@implementation ELCAssetTablePicker

@synthesize parent = _parent;;
@synthesize selectedAssetsLabel = _selectedAssetsLabel;
@synthesize assetGroup = _assetGroup;
@synthesize elcAssets = _elcAssets;
@synthesize singleSelection = _singleSelection;
@synthesize columns = _columns;

@synthesize minimumSelection;
@synthesize maximumSelection;

- (void)viewDidLoad
{
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    [self.tableView setAllowsSelection:NO];

    NSMutableArray *tempArray = [[NSMutableArray alloc] init];
    self.elcAssets = tempArray;
    [tempArray release];

    //Reset selection
    selectedCount = 0;

    if (self.immediateReturn) {

    } else {
        UIBarButtonItem *doneButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneAction:)] autorelease];
        [self.navigationItem setRightBarButtonItem:doneButtonItem];
        [self.navigationItem setTitle:localizedString(@"loading")];
    }

	[self performSelectorInBackground:@selector(preparePhotos) withObject:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.columns = self.view.bounds.size.width / 80;

    //Set done button status
    self.navigationItem.rightBarButtonItem.enabled = (minimumSelection == 0) || (selectedCount >= minimumSelection);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    self.columns = self.view.bounds.size.width / 80;
    [self.tableView reloadData];
}

- (void)preparePhotos
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSMutableArray * assets = [[NSMutableArray alloc] init];

    NSLog(@"enumerating photos");
    [self.assetGroup enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {

        if(result == nil) {
            return;
        }

        ELCAsset *elcAsset = [[ELCAsset alloc] initWithAsset:result];
        [elcAsset setParent:self];
        [assets addObject:elcAsset];
        [elcAsset release];
     }];
    NSLog(@"done enumerating photos");

    self.elcAssets = assets;
    [assets release];

    dispatch_sync(dispatch_get_main_queue(), ^{
        if (self.columns > 0) {
            [self reloadTable];
        }
    });

    [pool release];
}

- (void)reloadTable
{
    [self.tableView reloadData];
    // scroll to bottom
    int section = self.tableView.numberOfSections - 1;
    int row = [self.tableView numberOfRowsInSection:section] - 1;
    if (section >= 0 && row >= 0) {
        NSIndexPath *ip = [NSIndexPath indexPathForRow:row
                                             inSection:section];
        [self.tableView scrollToRowAtIndexPath:ip
                              atScrollPosition:UITableViewScrollPositionBottom
                                      animated:NO];
    }

    [self.navigationItem setTitle:localizedString(self.singleSelection ? @"pick_photo" : @"pick_photos")];
}

- (void)doneAction:(id)sender
{
	NSMutableArray *selectedAssetsImages = [[[NSMutableArray alloc] init] autorelease];

	for(ELCAsset *elcAsset in self.elcAssets) {

		if([elcAsset selected]) {

			[selectedAssetsImages addObject:[elcAsset asset]];
		}
	}

    [self.parent selectedAssets:selectedAssetsImages];
}

- (void)assetSelected:(id)asset
{
    if (self.singleSelection) {

        for(ELCAsset *elcAsset in self.elcAssets) {
            if(asset != elcAsset) {
                elcAsset.selected = NO;
            }
        }
    }
    if (self.immediateReturn) {
        NSArray *singleAssetArray = [NSArray arrayWithObject:[asset asset]];
        [(NSObject *)self.parent performSelector:@selector(selectedAssets:) withObject:singleAssetArray afterDelay:0];
    }
}

#pragma mark UITableViewDataSource Delegate Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.columns == 0)
        return 0;

    return (self.elcAssets.count + self.columns - 1) / self.columns;
}

- (NSArray *)assetsForIndexPath:(NSIndexPath *)path
{
    int index = path.row * self.columns;
    int length = MIN(self.columns, [self.elcAssets count] - index);
    return [self.elcAssets subarrayWithRange:NSMakeRange(index, length)];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView_ cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";

    ELCAssetCell *cell = (ELCAssetCell*)[tableView_ dequeueReusableCellWithIdentifier:CellIdentifier];

    if (cell == nil) {
        cell = [[[ELCAssetCell alloc] initWithAssets:[self assetsForIndexPath:indexPath] reuseIdentifier:CellIdentifier] autorelease];
        cell.delegate = self;

    } else {
		[cell setAssets:[self assetsForIndexPath:indexPath]];
	}

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {

	return 79;
}

- (int)totalSelectedAssets {

    int count = 0;

    for(ELCAsset *asset in self.elcAssets) {
		if([asset selected]) {
            count++;
		}
	}

    return count;
}

- (void)dealloc
{
    [_assetGroup release];
    [_elcAssets release];
    [_selectedAssetsLabel release];
    [super dealloc];
}

- (void)selectionChangedWithSelected:(NSNumber*)selected {

    @synchronized(self) {
        if (selected.boolValue) {
            selectedCount++;
        }
        else {

            selectedCount--;
            if (selectedCount < 0) {
                selectedCount = 0;
            }
        }
    }
}

// Image selection delegate

- (NSNumber*)canSelectMore {
    return [NSNumber numberWithBool:((maximumSelection == 0) || (selectedCount < maximumSelection))];
}

@end
