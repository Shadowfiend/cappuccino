/*
 * CPDragServer.j
 * AppKit
 *
 * Created by Francisco Tolmasky.
 * Copyright 2008, 280 North, Inc.
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

@import <AppKit/CPView.j>
@import <AppKit/CPEvent.j>
@import <AppKit/CPPasteboard.j>
@import <AppKit/CPImageView.j>

#import "CoreGraphics/CGGeometry.h"
#import "Platform/Platform.h"


CPDragOperationNone     = 0,
CPDragOperationCopy     = 1 << 1,
CPDragOperationLink     = 1 << 1,
CPDragOperationGeneric  = 1 << 2,
CPDragOperationPrivate  = 1 << 3,
CPDragOperationMove     = 1 << 4,
CPDragOperationDelete   = 1 << 5,
CPDragOperationEvery    = -1;

#define DRAGGING_WINDOW(anObject) ([anObject isKindOfClass:[CPWindow class]] ? anObject : [anObject window])

var    CPDragServerPreviousEvent      = nil,
CPDragServerAutoscrollInterval = nil;
/*
var CPDragServerAutoscroll = function()
{
    [CPDragServerSource autoscroll:CPDragServerPreviousEvent];
}

    if (CPDragServerAutoscrollInterval === nil)
    {
        if ([CPDragServerSource respondsToSelector:@selector(autoscroll:)])
            CPDragServerAutoscrollInterval = setInterval(CPDragServerAutoscroll, 100);
    }

    CPDragServerPreviousEvent = anEvent;

        if (CPDragServerAutoscrollInterval !== nil)
            clearInterval(CPDragServerAutoscrollInterval);

        CPDragServerAutoscrollInterval = nil;
*/

var CPSharedDragServer     = nil;

var CPDragServerSource             = nil;
var CPDragServerDraggingInfo       = nil;

/*
    CPDraggingInfo is a container of information about a specific dragging session.
    @ignore
*/
@implementation CPDraggingInfo : CPObject
{
}

- (CPPasteboard)draggingPasteboard
{
    if ([CPPlatform supportsDragAndDrop])
        return [_CPDOMDataTransferPasteboard DOMDataTransferPasteboard];

    return [[CPDragServer sharedDragServer] draggingPasteboard];
}

- (id)draggingSource
{
    return [[CPDragServer sharedDragServer] draggingSource];
}

/*
- (unsigned)draggingSourceOperationMask
*/

- (CPPoint)draggingLocation
{
    return [[CPDragServer sharedDragServer] draggingLocation];
}

- (CPWindow)draggingDestinationWindow
{
    return DRAGGING_WINDOW([[CPDragServer sharedDragServer] draggingDestination]);
}

- (CPImage)draggedImage
{
    return [[self draggedView] image];
}

- (CGPoint)draggedImageLocation
{
    return [self draggedViewLocation];
}

- (CPView)draggedView
{
    return [[CPDragServer sharedDragServer] draggedView];
}

- (CGPoint)draggedViewLocation
{
    var dragServer = [CPDragServer sharedDragServer];

    return [DRAGGING_WINDOW([dragServer draggingDestination]) convertPlatformWindowToBase:[[dragServer draggedView] frame].origin];
}

@end

var CPDraggingSource_draggedImage_movedTo_          = 1 << 0,
    CPDraggingSource_draggedImage_endAt_operation_  = 1 << 1,
    CPDraggingSource_draggedView_movedTo_           = 1 << 2,
    CPDraggingSource_draggedView_endedAt_operation_ = 1 << 3;

@implementation CPDragServer : CPObject
{
    BOOL            _isDragging @accessors(readonly, getter=isDragging);

    CPWindow        _draggedWindow @accessors(readonly, getter=draggedWindow);
    CPView          _draggedView @accessors(readonly, getter=draggedView);
    CPImageView     _imageView;

    BOOL            _isDraggingImage;

    CGSize          _draggingOffset @accessors(readonly, getter=draggingOffset);

    CPPasteboard    _draggingPasteboard @accessors(readonly, getter=draggingPasteboard);

    id              _draggingSource @accessors(readonly, getter=draggingSource);
    unsigned        _implementedDraggingSourceMethods;

    CGPoint         _draggingLocation;
    id              _draggingDestination;
}

/*
    Private Objective-J/Cappuccino method
    @ignore
*/
+ (void)initialize
{
    if (self !== [CPDragServer class])
        return;

    CPDragServerDraggingInfo = [[CPDraggingInfo alloc] init];
}

+ (CPDragServer)sharedDragServer
{
    if (!CPSharedDragServer)
        CPSharedDragServer = [[CPDragServer alloc] init];

    return CPSharedDragServer;
}

/*
    @ignore
*/
- (id)init
{
    self = [super init];

    if (self)
    {
        _draggedWindow = [[CPWindow alloc] initWithContentRect:_CGRectMakeZero() styleMask:CPBorderlessWindowMask];

        [_draggedWindow setLevel:CPDraggingWindowLevel];
    }

    return self;
}

- (CGPoint)draggingLocation
{
    return _draggingLocation
}

- (void)draggingStartedInPlatformWindow:(CPPlatformWindow)aPlatformWindow globalLocation:(CGPoint)aLocation
{
    if (_isDraggingImage)
    {
        if ([_draggingSource respondsToSelector:@selector(draggedImage:beganAt:)])
            [_draggingSource draggedImage:[_draggedView image] beganAt:aLocation];
    }
    else
    {
        if ([_draggingSource respondsToSelector:@selector(draggedView:beganAt:)])
            [_draggingSource draggedView:_draggedView beganAt:aLocation];
    }

    if (![CPPlatform supportsDragAndDrop])
        [_draggedWindow orderFront:self];
}

- (void)draggingSourceUpdatedWithGlobalLocation:(CGPoint)aGlobalLocation
{
    if (![CPPlatform supportsDragAndDrop])
        [_draggedWindow setFrameOrigin:_CGPointMake(aGlobalLocation.x - _draggingOffset.width, aGlobalLocation.y - _draggingOffset.height)];

    if (_implementedDraggingSourceMethods & CPDraggingSource_draggedImage_movedTo_)
        [_draggingSource draggedImage:[_draggedView image] movedTo:aGlobalLocation];

    else if (_implementedDraggingSourceMethods & CPDraggingSource_draggedView_movedTo_)
        [_draggingSource draggedView:_draggedView movedTo:aGlobalLocation];
}

- (CPDragOperation)draggingUpdatedInPlatformWindow:(CPPlatformWindow)aPlatformWindow location:(CGPoint)aLocation
{
    var dragOperation = CPDragOperationCopy;
    // We have to convert base to bridge since the drag event comes from the source window, not the drag window.
    var draggingDestination = [aPlatformWindow _dragHitTest:aLocation pasteboard:[CPDragServerDraggingInfo draggingPasteboard]];

    if (draggingDestination)
        _draggingLocation = [DRAGGING_WINDOW(draggingDestination) convertPlatformWindowToBase:aLocation];

    if(draggingDestination !== _draggingDestination)
    {
        if (_draggingDestination && [_draggingDestination respondsToSelector:@selector(draggingExited:)])
            [_draggingDestination draggingExited:CPDragServerDraggingInfo];

        _draggingDestination = draggingDestination;

        if (_draggingDestination && [_draggingDestination respondsToSelector:@selector(draggingEntered:)])
            dragOperation = [_draggingDestination draggingEntered:CPDragServerDraggingInfo];
    }
    else if (_draggingDestination && [_draggingDestination respondsToSelector:@selector(draggingUpdated:)])
        dragOperation = [_draggingDestination draggingUpdated:CPDragServerDraggingInfo];

    if (!_draggingDestination)
        dragOperation = CPDragOperationNone;

    return dragOperation;
}

- (void)draggingEndedInPlatformWindow:(CPPlatformWindow)aPlatformWindow globalLocation:(CGPoint)aLocation
{
    [_draggedView removeFromSuperview];

    if (![CPPlatform supportsDragAndDrop])
        [_draggedWindow orderOut:self];

    if (_implementedDraggingSourceMethods & CPDraggingSource_draggedImage_endAt_operation_)
        [_draggingSource draggedImage:[_draggedView image] endedAt:aLocation operation:NO];

    else if (_implementedDraggingSourceMethods & CPDraggingSource_draggedView_endedAt_operation_)
        [_draggingSource draggedView:_draggedView endedAt:aLocation operation:NO];

    _isDragging = NO;
}

- (void)performDragOperationInPlatformWindow:(CPPlatformWindow)aPlatformWindow
{
    if (_draggingDestination && 
        (![_draggingDestination respondsToSelector:@selector(prepareForDragOperation:)] || [_draggingDestination prepareForDragOperation:CPDragServerDraggingInfo]) && 
        (![_draggingDestination respondsToSelector:@selector(performDragOperation:)] || [_draggingDestination performDragOperation:CPDragServerDraggingInfo]) &&
        [_draggingDestination respondsToSelector:@selector(concludeDragOperation:)])
        [_draggingDestination concludeDragOperation:CPDragServerDraggingInfo];
}

/*!
    Initiates a drag session.
    @param aView the view being dragged
    @param aWindow the window where the drag source is
    @param viewLocation
    @param mouseOffset
    @param anEvent
    @param aPasteboard the pasteboard that contains the drag data
    @param aSourceObject the object where the drag started
    @param slideBack if \c YES, \c aView slides back to
    its origin on a failed drop
*/
- (void)dragView:(CPView)aView fromWindow:(CPWindow)aWindow at:(CGPoint)viewLocation offset:(CGSize)mouseOffset event:(CPEvent)mouseDownEvent pasteboard:(CPPasteboard)aPasteboard source:(id)aSourceObject slideBack:(BOOL)slideBack
{
    _isDragging = YES;

    _draggedView = aView;
    _draggingPasteboard = aPasteboard || [CPPasteboard pasteboardWithName:CPDragPboard];
    _draggingSource = aSourceObject;
    _draggingDestination = nil;

    // The offset is based on the distance from where we want the view to be initially from where the mouse is initially
    // Hence the use of mouseDownEvent's location and view's location in global coordinates.
    var mouseDownWindow = [mouseDownEvent window],
        mouseDownEventLocation = [mouseDownEvent locationInWindow];

    if (mouseDownEventLocation)
    {
        if (mouseDownWindow)
            mouseDownEventLocation = [mouseDownWindow convertBaseToGlobal:mouseDownEventLocation];

        _draggingOffset = _CGSizeMake(mouseDownEventLocation.x - viewLocation.x, mouseDownEventLocation.y - viewLocation.y);
    }
    else
        _draggingOffset = _CGSizeMakerZero();

    if ([CPPlatform isBrowser])
        [_draggedWindow setPlatformWindow:[aWindow platformWindow]];

    [aView setFrameOrigin:_CGPointMakeZero()];

    var mouseLocation = [CPEvent mouseLocation];

    // Place it where the mouse pointer is.
    [_draggedWindow setFrameOrigin:_CGPointMake(mouseLocation.x - _draggingOffset.width, mouseLocation.y - _draggingOffset.height)];
    [_draggedWindow setFrameSize:[aView frame].size];

    [[_draggedWindow contentView] addSubview:aView];

    _implementedDraggingSourceMethods = 0;

    if (_draggedView === _imageView)
    {
        if ([_draggingSource respondsToSelector:@selector(draggedImage:movedTo:)])
            _implementedDraggingSourceMethods |= CPDraggingSource_draggedImage_movedTo_;

        if ([_draggingSource respondsToSelector:@selector(draggedImage:endAt:operation:)])
            _implementedDraggingSourceMethods |= CPDraggingSource_draggedImage_endAt_operation_;
    }
    else
    {
        if ([_draggingSource respondsToSelector:@selector(draggedView:movedTo:)])
            _implementedDraggingSourceMethods |= CPDraggingSource_draggedView_movedTo_;

        if ([_draggingSource respondsToSelector:@selector(draggedView:endedAt:operation:)])
            _implementedDraggingSourceMethods |= CPDraggingSource_draggedView_endedAt_operation_;
    }

    if (![CPPlatform supportsDragAndDrop])
    {
        [self draggingStartedInPlatformWindow:[aWindow platformWindow] globalLocation:mouseLocation];
        [self trackDragging:mouseDownEvent];
    }
}

/*!
    Initiates a drag session.
    @param anImage the image to be dragged
    @param aWindow the source window of the drag session
    @param imageLocation
    @param mouseOffset
    @param anEvent
    @param aPasteboard the pasteboard where the drag data is located
    @param aSourceObject the object where the drag started
    @param slideBack if \c YES, \c aView slides back to
    its origin on a failed drop
*/
- (void)dragImage:(CPImage)anImage fromWindow:(CPWindow)aWindow at:(CGPoint)imageLocation offset:(CGSize)mouseOffset event:(CPEvent)anEvent pasteboard:(CPPasteboard)aPasteboard source:(id)aSourceObject slideBack:(BOOL)slideBack
{
    _isDraggingImage = YES;

    var imageSize = [anImage size];

    if (!_imageView)
        _imageView = [[CPImageView alloc] initWithFrame:_CGRectMake(0.0, 0.0, imageSize.width, imageSize.height)];

    [_imageView setImage:anImage];

    [self dragView:_imageView fromWindow:aWindow at:imageLocation offset:mouseOffset event:anEvent pasteboard:aPasteboard source:aSourceObject slideBack:slideBack];
}

- (void)trackDragging:(CPEvent)anEvent
{
    var type = [anEvent type],
        platformWindow = [_draggedWindow platformWindow],
        platformWindowLocation = [[anEvent window] convertBaseToPlatformWindow:[anEvent locationInWindow]];

    if (type === CPLeftMouseUp)
    {
        [self performDragOperationInPlatformWindow:platformWindow];
        [self draggingEndedInPlatformWindow:platformWindow globalLocation:platformWindowLocation];

        // Stop tracking events.
        return;
    }

    [self draggingSourceUpdatedWithGlobalLocation:platformWindowLocation];
    [self draggingUpdatedInPlatformWindow:platformWindow location:platformWindowLocation];

    // If we're not a mouse up, then we're going to want to grab the next event.
    [CPApp setTarget:self selector:@selector(trackDragging:)
        forNextEventMatchingMask:CPMouseMovedMask | CPLeftMouseDraggedMask | CPLeftMouseUpMask
        untilDate:nil inMode:0 dequeue:NO];
}

@end

@implementation CPWindow (CPDraggingAdditions)

/* @ignore */
- (id)_dragHitTest:(CGPoint)aPoint pasteboard:(CPPasteboard)aPasteboard
{
    // If none of our views or ourselves has registered for drag events...
    if (!_inclusiveRegisteredDraggedTypes)
        return nil;

// We don't need to do this because the only place this gets called
// -_dragHitTest: in CPPlatformWindow does this already. Perhaps to
// be safe?
//    if (![self containsPoint:aPoint])
//        return nil;

    var adjustedPoint = [self convertPlatformWindowToBase:aPoint],
        hitView = [_windowView hitTest:adjustedPoint];

    while (hitView && ![aPasteboard availableTypeFromArray:[hitView registeredDraggedTypes]])
        hitView = [hitView superview];

    if (hitView)
        return hitView;

    if ([aPasteboard availableTypeFromArray:[self registeredDraggedTypes]])
        return self;

    return nil;
}

@end
