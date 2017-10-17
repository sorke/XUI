//
//  XUIEditableListViewController.m
//  XUI
//
//  Created by Zheng on 15/10/2017.
//

#import "XUIEditableListViewController.h"
#import "XUIEditableListCell.h"

#import "XUIPrivate.h"
#import "XUITheme.h"
#import "XUIOptionModel.h"
#import "XUIBaseOptionCell.h"

#import "XUIEditableListItemViewController.h"

@interface XUIEditableListViewController () <UITableViewDelegate, UITableViewDataSource, XUIEditableListItemViewControllerDelegate>

@property (nonatomic, assign) BOOL needsUpdate;

@property (nonatomic, strong) XUIBaseOptionCell *addCell;
@property (nonatomic, strong) XUIBaseOptionCell *deleteCell;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray <NSString *> *mutableContentList;
@property (nonatomic, assign) NSUInteger editingIndex;

@end

@implementation XUIEditableListViewController

- (instancetype)initWithCell:(XUIEditableListCell *)cell {
    if (self = [super init]) {
        _cell = cell;
        _mutableContentList = [[NSMutableArray alloc] init];
        _editingIndex = UINT_MAX;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSArray <NSString *> *originalList = self.cell.xui_value;
    for (NSString *item in originalList) {
        if ([item isKindOfClass:[NSString class]]) {
            [self.mutableContentList addObject:item];
        }
    }
    
    [self.navigationItem setRightBarButtonItem:self.editButtonItem];
    
    [self.tableView registerClass:[XUIBaseOptionCell class] forCellReuseIdentifier:XUIBaseOptionCellReuseIdentifier];
    [self.view addSubview:self.tableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateIfNeeded];
}

- (BOOL)isEditing {
    return [self.tableView isEditing];
}

- (void)setEditing:(BOOL)editing {
    [super setEditing:editing];
    [self.tableView setEditing:editing];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
    [self updateSelectionCount];
}

#pragma mark - Getters

- (NSArray <NSString *> *)contentList {
    return [self.mutableContentList copy];
}

#pragma mark - UIView Getters

- (XUIBaseOptionCell *)addCell {
    if (!_addCell) {
        XUIBaseOptionCell *cell = [[XUIBaseOptionCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                           reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.adapter = self.adapter;
        cell.internalIcon = @"XUIEditableListIconAdd.png";
        cell.xui_label = NSLocalizedStringFromTableInBundle(@"Add item...", nil, FRAMEWORK_BUNDLE, nil);
        [cell setTheme:self.theme];
        _addCell = cell;
    }
    return _addCell;
}

- (XUIBaseOptionCell *)deleteCell {
    if (!_deleteCell) {
        XUIBaseOptionCell *cell = [[XUIBaseOptionCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                           reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.adapter = self.adapter;
        cell.internalIcon = @"XUIEditableListIconManage.png";
        cell.xui_label = NSLocalizedStringFromTableInBundle(@"Manage Items", nil, FRAMEWORK_BUNDLE, nil);
        [cell setTheme:self.theme];
        _deleteCell = cell;
    }
    return _deleteCell;
}

- (UITableView *)tableView {
    if (!_tableView) {
        UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
        tableView.delegate = self;
        tableView.dataSource = self;
        tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        tableView.editing = NO;
        tableView.allowsSelection = YES;
        tableView.allowsMultipleSelection = NO;
        tableView.allowsSelectionDuringEditing = YES;
        tableView.allowsMultipleSelectionDuringEditing = YES;
        XUI_START_IGNORE_PARTIAL
        if (XUI_SYSTEM_9) {
            tableView.cellLayoutMarginsFollowReadableWidth = NO;
        }
        XUI_END_IGNORE_PARTIAL
        _tableView = tableView;
    }
    return _tableView;
}

#pragma mark - UITableViewDelegate & UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 2;
    } else if (section == 2) {
        return self.mutableContentList.count;
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 56.f;
    }
    return 44.f;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    header.textLabel.font = [UIFont systemFontOfSize:14.0];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (1 == section) {
        NSUInteger itemCount = self.mutableContentList.count;
        NSString *shortTitle = nil;
        if (itemCount == 0) {
            shortTitle =  NSLocalizedStringFromTableInBundle(@"Item List (No Item)", nil, FRAMEWORK_BUNDLE, nil);
        } else if (itemCount == 1) {
            shortTitle = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Item List (%lu Item)", nil, FRAMEWORK_BUNDLE, nil), (unsigned long)itemCount];
        } else {
            shortTitle = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Item List (%lu Items)", nil, FRAMEWORK_BUNDLE, nil), (unsigned long)itemCount];
        }
        return shortTitle;
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (1 == section) {
        return [self.adapter localizedStringForKey:self.cell.xui_footerText value:self.cell.xui_footerText];
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            return self.addCell;
        }
        else if (indexPath.row == 1) {
            return self.deleteCell;
        }
    } else if (indexPath.section == 2) {
        XUIBaseOptionCell *cell =
        [tableView dequeueReusableCellWithIdentifier:XUIBaseOptionCellReuseIdentifier];
        if (nil == cell)
        {
            cell = [[XUIBaseOptionCell alloc] initWithStyle:UITableViewCellStyleDefault
                                            reuseIdentifier:XUIBaseOptionCellReuseIdentifier];
        }
        cell.adapter = self.adapter;
        NSUInteger idx = indexPath.row;
        if (idx < self.mutableContentList.count) {
            cell.xui_label = self.mutableContentList[idx];
        }
        cell.accessoryType = UITableViewCellAccessoryDetailButton;
        cell.showsReorderControl = YES;
        [cell setTheme:self.theme];
        return cell;
    }
    return [XUIBaseCell new];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        if (indexPath.row == 0) {
            [self presentItemViewControllerAtIndexPath:indexPath withItemContent:nil];
        } else if (indexPath.row == 1) {
            NSArray <NSIndexPath *> *selectedIndexPathes = [self.tableView indexPathsForSelectedRows];
            if (tableView.isEditing && selectedIndexPathes.count > 0) {
                NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
                for (NSIndexPath *indexPath in selectedIndexPathes) {
                    [indexSet addIndex:indexPath.row];
                }
                [self.mutableContentList removeObjectsAtIndexes:[indexSet copy]];
                [tableView beginUpdates];
                [tableView deleteRowsAtIndexPaths:selectedIndexPathes withRowAnimation:UITableViewRowAnimationAutomatic];
                [tableView endUpdates];
                [self updateSelectionCount];
                [self notifyContentListUpdate];
            } else {
                [self setEditing:![self.tableView isEditing] animated:YES];
            }
        }
    }
    else if (indexPath.section == 2) {
        if (!tableView.isEditing) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
        } else {
            [self updateSelectionCount];
        }
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self updateSelectionCount];
}

- (void)updateSelectionCount {
    NSString *deleteLabel = nil;
    NSString *deleteIcon = nil;
    NSUInteger selectedCount = [self.tableView indexPathsForSelectedRows].count;
    if (self.tableView.isEditing && selectedCount > 0) {
        if (selectedCount == 1) {
            deleteLabel = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Delete selected %lu item", nil, FRAMEWORK_BUNDLE, nil), selectedCount];
        } else {
            deleteLabel = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Delete selected %lu items", nil, FRAMEWORK_BUNDLE, nil), selectedCount];
        }
        deleteIcon = @"XUIEditableListIconDelete.png";
    } else {
        deleteLabel = NSLocalizedStringFromTableInBundle(@"Manage Items", nil, FRAMEWORK_BUNDLE, nil);
        deleteIcon = @"XUIEditableListIconManage.png";
    }
    self.deleteCell.xui_label = deleteLabel;
    self.deleteCell.internalIcon = deleteIcon;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 2) {
        return YES;
    }
    return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 2) {
        return UITableViewCellEditingStyleDelete;
    }
    return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if (indexPath.section == 2) {
            [self.mutableContentList removeObjectAtIndex:indexPath.row];
            [tableView beginUpdates];
            [tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
            [tableView endUpdates];
            [self updateSelectionCount];
            [self notifyContentListUpdate];
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 2) {
        return YES;
    }
    return NO;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    if (sourceIndexPath.section == 2 && proposedDestinationIndexPath.section == 2) {
        return proposedDestinationIndexPath;
    }
    return sourceIndexPath;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if (sourceIndexPath.section == 2 && destinationIndexPath.section == 2) {
        [self.mutableContentList exchangeObjectAtIndex:sourceIndexPath.row withObjectAtIndex:destinationIndexPath.row];
        [self notifyContentListUpdate];
    }
}

XUI_START_IGNORE_PARTIAL
- (NSArray <UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 2) {
        __weak typeof(self) weak_self = self;
        UITableViewRowAction *button = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:NSLocalizedStringFromTableInBundle(@"Delete", nil, FRAMEWORK_BUNDLE, nil) handler:^(UITableViewRowAction *action, NSIndexPath *indexPath)
                                        {
                                            __strong typeof(weak_self) self = weak_self;
                                            [self tableView:tableView commitEditingStyle:UITableViewCellEditingStyleDelete forRowAtIndexPath:indexPath];
                                        }];
        button.backgroundColor = self.theme.dangerColor;
        return @[button];
    }
    return @[];
}
XUI_END_IGNORE_PARTIAL

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 2) {
        XUIBaseCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        [self presentItemViewControllerAtIndexPath:indexPath withItemContent:cell.xui_label];
    }
}

#pragma mark - Item

- (void)presentItemViewControllerAtIndexPath:(NSIndexPath *)indexPath withItemContent:(NSString *)content {
    if (indexPath.section == 2) {
        self.editingIndex = indexPath.row;
    } else {
        self.editingIndex = UINT_MAX;
    }
    XUIEditableListItemViewController *itemViewController = [[XUIEditableListItemViewController alloc] initWithContent:content];
    itemViewController.cellFactory.theme = self.cellFactory.theme;
    itemViewController.cellFactory.adapter = self.cellFactory.adapter;
    itemViewController.delegate = self;
    [self.navigationController pushViewController:itemViewController animated:YES];
}

#pragma mark - XUIEditableListItemViewControllerDelegate

- (void)editableListItemViewController:(XUIEditableListItemViewController *)controller contentUpdated:(NSString *)content {
    if (controller.isAddMode) {
        [self.mutableContentList insertObject:content atIndex:0];
    } else {
        if (self.editingIndex < self.mutableContentList.count) {
            // Update Value
            [self.mutableContentList replaceObjectAtIndex:self.editingIndex withObject:content];
        }
    }
    [self.navigationController popToViewController:self animated:YES];
    [self setNeedsUpdate];
    [self notifyContentListUpdate];
}

- (void)setNeedsUpdate {
    self.needsUpdate = YES;
}

- (void)updateIfNeeded {
    if (self.needsUpdate) {
        self.needsUpdate = NO;
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)] withRowAnimation:UITableViewRowAnimationAutomatic];
        [self updateSelectionCount];
    }
}

#pragma mark - Update

- (void)notifyContentListUpdate {
    self.cell.xui_value = self.contentList;
    if ([_delegate respondsToSelector:@selector(editableListViewControllerContentListChanged:)]) {
        [_delegate editableListViewControllerContentListChanged:self];
    }
}

#pragma mark - Memory

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"- [XUIEditableListViewController dealloc]");
#endif
}

@end
