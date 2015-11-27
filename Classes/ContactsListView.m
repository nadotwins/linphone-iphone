/* ContactsViewController.m
 *
 * Copyright (C) 2012  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#import "PhoneMainView.h"
#import <AddressBook/ABPerson.h>

@implementation ContactSelection

static ContactSelectionMode sSelectionMode = ContactSelectionModeNone;
static NSString *sAddAddress = nil;
static NSString *sSipFilter = nil;
static BOOL sEnableEmailFilter = FALSE;
static NSString *sNameOrEmailFilter;

+ (void)setSelectionMode:(ContactSelectionMode)selectionMode {
	sSelectionMode = selectionMode;
}

+ (ContactSelectionMode)getSelectionMode {
	return sSelectionMode;
}

+ (void)setAddAddress:(NSString *)address {
	if (sAddAddress != nil) {
		sAddAddress = nil;
	}
	if (address != nil) {
		sAddAddress = address;
	}
}

+ (NSString *)getAddAddress {
	return sAddAddress;
}

+ (void)setSipFilter:(NSString *)domain {
	sSipFilter = domain;
}

+ (NSString *)getSipFilter {
	return sSipFilter;
}

+ (void)enableEmailFilter:(BOOL)enable {
	sEnableEmailFilter = enable;
}

+ (BOOL)emailFilterEnabled {
	return sEnableEmailFilter;
}

+ (void)setNameOrEmailFilter:(NSString *)fuzzyName {
	sNameOrEmailFilter = fuzzyName;
}

+ (NSString *)getNameOrEmailFilter {
	return sNameOrEmailFilter;
}

@end

@implementation ContactsListView

@synthesize tableController;
@synthesize allButton;
@synthesize linphoneButton;
@synthesize addButton;
@synthesize topBar;

typedef enum { ContactsAll, ContactsLinphone, ContactsMAX } ContactsCategory;

#pragma mark - UICompositeViewDelegate Functions

static UICompositeViewDescription *compositeDescription = nil;

+ (UICompositeViewDescription *)compositeViewDescription {
	if (compositeDescription == nil) {
		compositeDescription = [[UICompositeViewDescription alloc] init:self.class
															  statusBar:StatusBarView.class
																 tabBar:TabBarView.class
															   sideMenu:SideMenuView.class
															 fullscreen:false
														  landscapeMode:LinphoneManager.runningOnIpad
														   portraitMode:true];
	}
	return compositeDescription;
}

- (UICompositeViewDescription *)compositeViewDescription {
	return self.class.compositeViewDescription;
}

#pragma mark - ViewController Functions

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	_searchBar.showsCancelButton = (_searchBar.text.length > 0);

	if (tableController.isEditing) {
		tableController.editing = NO;
	}
	[self update];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (![FastAddressBook isAuthorized]) {
		UIAlertView *error = [[UIAlertView alloc]
				initWithTitle:NSLocalizedString(@"Address book", nil)
					  message:NSLocalizedString(@"You must authorize the application to have access to address book.\n"
												 "Toggle the application in Settings > Privacy > Contacts",
												nil)
					 delegate:nil
			cancelButtonTitle:NSLocalizedString(@"Continue", nil)
			otherButtonTitles:nil];
		[error show];
		[PhoneMainView.instance changeCurrentView:DialerView.compositeViewDescription];
	}
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[self changeView:ContactsAll];
}

#pragma mark -

- (void)changeView:(ContactsCategory)view {
	CGRect frame = _selectedButtonImage.frame;
	if (view == ContactsAll) {
		frame.origin.x = allButton.frame.origin.x;
		[ContactSelection setSipFilter:nil];
		[ContactSelection enableEmailFilter:FALSE];
		[tableController loadData];
		allButton.selected = TRUE;
		linphoneButton.selected = FALSE;
	} else {
		frame.origin.x = linphoneButton.frame.origin.x;
		[ContactSelection setSipFilter:LinphoneManager.instance.contactFilter];
		[ContactSelection enableEmailFilter:FALSE];
		[tableController loadData];
		linphoneButton.selected = TRUE;
		allButton.selected = FALSE;
	}
	_selectedButtonImage.frame = frame;
}

- (void)refreshButtons {
	[addButton setHidden:FALSE];
	[self changeView:[ContactSelection getSipFilter] ? ContactsLinphone : ContactsAll];
}

- (void)update {
	[self refreshButtons];
	[tableController loadData];
}

#pragma mark - Action Functions

- (IBAction)onAllClick:(id)event {
	[self changeView:ContactsAll];
}

- (IBAction)onLinphoneClick:(id)event {
	[self changeView:ContactsLinphone];
}

- (IBAction)onAddContactClick:(id)event {
	// Go to Contact details view
	ContactDetailsView *view = VIEW(ContactDetailsView);
	[PhoneMainView.instance changeCurrentView:view.compositeViewDescription push:TRUE];
	if ([ContactSelection getAddAddress] == nil) {
		[view newContact];
	} else {
		[view newContact:[ContactSelection getAddAddress]];
	}
}

- (IBAction)onDeleteClick:(id)sender {
	NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"Do you want to delete selected contact?", nil)];
	[UIConfirmationDialog ShowWithMessage:msg
		cancelMessage:nil
		confirmMessage:nil
		onCancelClick:^() {
		  [self onEditionChangeClick:nil];
		}
		onConfirmationClick:^() {
		  [tableController removeSelectionUsing:nil];
		  [tableController loadData];
		}];
}

- (IBAction)onEditionChangeClick:(id)sender {
	allButton.hidden = linphoneButton.hidden = _selectedButtonImage.hidden = addButton.hidden =
		self.tableController.isEditing;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	[self searchBar:searchBar textDidChange:@""];
	[searchBar resignFirstResponder];
}

#pragma mark - Rotation handling

//- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
//	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
//	// the searchbar overlaps the subview in most rotation cases, we have to re-layout the view manually:
//	[self relayoutTableView];
//}

#pragma mark - ABPeoplePickerDelegate

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker {
	[PhoneMainView.instance popCurrentView];
	return;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker
	  shouldContinueAfterSelectingPerson:(ABRecordRef)person {
	return true;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker
	  shouldContinueAfterSelectingPerson:(ABRecordRef)person
								property:(ABPropertyID)property
							  identifier:(ABMultiValueIdentifier)identifier {

	CFTypeRef multiValue = ABRecordCopyValue(person, property);
	CFIndex valueIdx = ABMultiValueGetIndexForIdentifier(multiValue, identifier);
	NSString *phoneNumber = (NSString *)CFBridgingRelease(ABMultiValueCopyValueAtIndex(multiValue, valueIdx));
	// Go to dialer view
	DialerView *view = VIEW(DialerView);
	[PhoneMainView.instance changeCurrentView:view.compositeViewDescription];
	[view call:phoneNumber displayName:(NSString *)CFBridgingRelease(ABRecordCopyCompositeName(person))];
	CFRelease(multiValue);
	return false;
}

#pragma mark - searchBar delegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	// display searchtext in UPPERCASE
	// searchBar.text = [searchText uppercaseString];
	searchBar.showsCancelButton = (searchText.length > 0);
	[ContactSelection setNameOrEmailFilter:searchText];
	[tableController loadData];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:FALSE animated:TRUE];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:TRUE animated:TRUE];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

@end