/*
 * CPViewController.j
 * AppKit
 *
 * Created by Nicholas Small and Francisco Tolmasky.
 * Copyright 2009, 280 North, Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

@import <AppKit/CPResponder.j>


/*! @class CPViewController
    The CPViewController class provides the fundamental view-management controller for Cappuccino applications.
    The basic view controller class supports the presentation of an associated view in addition to basic support
    for managing modal views and, in the future, animations. Subclasses such as CPNavigationController and
    CPTabBarController provide additional behavior for managing complex hierarchies of view controllers and views.

    You use each instance of CPViewController to manage a single view (and hierarchy). For a simple view controller,
    this entails managing the view hierarchy responsible for presenting your application content.
    A typical view hierarchy consists of a root view�a reference to which is available in the view property of this class�
    and one or more subviews presenting the actual content. In the case of navigation and tab bar controllers, the view
    controller manages not only the high-level view hierarchy (which provides the navigation controls) but also one
    or more additional view controllers that handle the presentation of the application content.

    Unlike UIViewController in Cocoa Touch, a CPViewController does not represent an entire screen of content. You
    will add your root view to an existing view or window's content view. You can manage many view controllers
    on screen at once. CPViewController is also the preferred way of working with Cibs.

    Subclasses can override -loadView to create their custom view hierarchy, or specify a cib name to be loaded automatically.
    It has methods that are called when a view appears or disappears.
    This class is also a good place for delegate & datasource methods, and other controller stuff.
*/
@implementation CPViewController : CPResponder
{
    CPView          _view;

    id              _representedObject @accessors(property=representedObject);
    CPString        _title @accessors(property=title);

    CPString        _cibName @accessors(property=cibName, readonly);
    CPBundle        _cibBundle @accessors(property=cibBundle, readonly);
    CPDictionary    _cibExternalNameTable @accessors(property=cibExternalNameTable, readonly);
}

/*!
    Convenience initializer calls -initWithCibName:bundle: with nil for both parameters.
*/
- (id)init
{
    return [self initWithCibName:nil bundle:nil];
}

- (id)initWithCibName:(CPString)aCibNameOrNil bundle:(CPBundle)aCibBundleOrNil
{
    return [self initWithCibName:aCibNameOrNil bundle:aCibBundleOrNil externalNameTable:nil];
}

- (id)initWithCibName:(CPString)aCibNameOrNil bundle:(CPBundle)aCibBundleOrNil owner:(id)anOwner
{
    return [self initWithCibName:aCibNameOrNil bundle:aCibBundleOrNil externalNameTable:[CPDictionary dictionaryWithObject:anOwner forKey:CPCibOwner]];
}

/*!
    The designated initializer. If you subclass CPViewController, you must call the super implementation of this method, even if you aren't using a Cib.
    In the specified Cib, the File's Owner proxy should have its class set to your view controller subclass, with the view outlet connected to the main view.
    If you pass in a nil Cib name, then you must either call -setView: before -view is invoked, or override -loadView to set up your views.

    @param cibNameOrNil The path to the cib to load for the root view or nil to programmatically create views.
    @param cibBundleOrNil The bundle that the cib is located in or nil for the main bundle.
*/
- (id)initWithCibName:(CPString)aCibNameOrNil bundle:(CPBundle)aCibBundleOrNil externalNameTable:(CPDictionary)anExternalNameTable
{
    self = [super init];

    if (self)
    {
        // Don't load the cib until someone actually requests the view. The user may just be intending to use setView:.
        _cibName = aCibNameOrNil;
        _cibBundle = aCibBundleOrNil || [CPBundle mainBundle];
        _cibExternalNameTable = anExternalNameTable || [CPDictionary dictionaryWithObject:self forKey:CPCibOwner];
    }

    return self;
}

/*!
    Programmatically creates the view that the controller manages.
    You should never call this method directly. The view controller calls this method when the view property is requested but is nil.

    If you create your views manually, you must override this method and use it to create your view and assign it to the view property.
    The default implementation for programmatic views is to create a plain view. You can invoke super to utilize this view.

    If you use Interface Builder to create your views and initialize the view controller�that is, you initialize the view using the
    initWithCibName:bundle: method�then you must not override this method. The consequences risk shattering the space-time continuum.

    Note: The cib loading system is currently asynchronous.
*/
- (void)loadView
{
    if (_view)
        return;

//    if (_cibName)
//        [CPException raise: reason:];

    var cib = [[CPCib alloc] initWithContentsOfURL:[_cibBundle pathForResource:_cibName + @".cib"]];

    [cib instantiateCibWithExternalNameTable:_cibExternalNameTable];
}

/*!
    Returns the view that the controller manages.
    If this property is nil, the controller sends loadView to itself to create the view that it manages.
    Subclasses should override the loadView method to create any custom views. The default value is nil.

    Note: An error will not be thrown if after -loadView, the view property is still nil. -view will simply return nil, but will continue to call -loadView on subsequent calls.
*/
- (CPView)view
{
    if (!_view)
    {
        var cibOwner = [_cibExternalNameTable objectForKey:CPCibOwner];

        if ([cibOwner respondsToSelector:@selector(viewControllerWillLoadCib:)])
            [cibOwner viewControllerWillLoadCib:self];

        [self loadView];

        if (_view === nil && [cibOwner isKindOfClass:[CPDocument class]])
            [self setView:[cibOwner valueForKey:@"view"]];

        if ([cibOwner respondsToSelector:@selector(viewControllerDidLoadCib:)])
            [cibOwner viewControllerDidLoadCib:self];
    }

    return _view;
}


/*!
    Manually sets the view that the controller manages.
    Setting to nil will cause -loadView to be called on all subsequent calls of -view.

    @param aView The view this controller should represent.
*/
- (void)setView:(CPView)aView
{
    _view = aView;
}

@end


var CPViewControllerViewKey     = @"CPViewControllerViewKey",
    CPViewControllerTitleKey    = @"CPViewControllerTitleKey";

@implementation CPViewController (CPCoding)

/*!
    Initializes the view item by unarchiving data from a coder.
    @param aCoder the coder from which the data will be unarchived
    @return the initialized collection view item
*/
- (id)initWithCoder:(CPCoder)aCoder
{
    self = [super initWithCoder:aCoder];

    if (self)
    {
        _view = [aCoder decodeObjectForKey:CPViewControllerViewKey];
        _title = [aCoder decodeObjectForKey:CPViewControllerTitleKey];
    }

    return self;
}

/*!
    Archives the colletion view item to the provided coder.
    @param aCoder the coder to which the view item should be archived
*/
- (void)encodeWithCoder:(CPCoder)aCoder
{
    [super encodeWithCoder:aCoder];

    [aCoder encodeObject:_view forKey:CPViewControllerViewKey];
    [aCoder encodeObject:_title forKey:CPViewControllerTitleKey];
}

@end
