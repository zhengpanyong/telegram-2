//
//  TGModalGifSearch.m
//  Telegram
//
//  Created by keepcoder on 03/12/15.
//  Copyright © 2015 keepcoder. All rights reserved.
//

#import "TGModalGifSearch.h"
#import "TMTableView.h"
#import "TMSearchTextField.h"
#import "UIImageView+AFNetworking.h"
#import "SpacemanBlocks.h"

@interface TGGifSearchRowItem : TMRowItem
@property (nonatomic,strong) NSArray *gifs;
@property (nonatomic,assign) long randKey;
@end

@implementation TGGifSearchRowItem

-(id)initWithObject:(id)object {
    if(self = [super initWithObject:object]) {
        _gifs = object;
        _randKey = rand_long();
    }
    
    return self;
}

-(NSUInteger)hash {
    return _randKey;
}

@end


@interface TGGifSearchRowView : TMRowView
@property (nonatomic, strong) NSTrackingArea *trackingArea;
@end


@implementation TGGifSearchRowView

-(instancetype)initWithFrame:(NSRect)frameRect {
    if(self = [super initWithFrame:frameRect]) {
        
        int s = NSHeight(frameRect);
        
        for (int i = 0; i < 4; i++) {
            NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(i == 0 ? 10 : 10 + (i*s) + (2*i), 1, s, s-2)];
            
            imageView.wantsLayer = YES;
            imageView.layer.cornerRadius = 4;
            imageView.layer.borderWidth = 1;
            imageView.layer.borderColor = GRAY_BORDER_COLOR.CGColor;
            [self addSubview:imageView];
        
        }
        
    }
    
    return self;
}


-(void)redrawRow {
    [super redrawRow];
    
    TGGifSearchRowItem *item = (TGGifSearchRowItem *)[self rowItem];
    
    [self.subviews enumerateObjectsUsingBlock:^(NSImageView * imageView, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if(idx < item.gifs.count) {
            TL_foundGifExternal *gif = item.gifs[idx];
            [imageView setImageWithURL:[NSURL URLWithString:gif.thumb_url]];
            [imageView setImageScaling:NSImageScaleAxesIndependently];
        } else {
            imageView.image = nil;
        }
    
    }];
    
    
}

-(void)updateTrackingAreas
{
    if(_trackingArea != nil) {
        [self removeTrackingArea:_trackingArea];
    }
    
    
    int opts = (NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect);
    _trackingArea = [ [NSTrackingArea alloc] initWithRect:[self bounds]
                                                  options:opts
                                                    owner:self
                                                 userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

-(void)mouseMoved:(NSEvent *)theEvent {
    [super mouseMoved:theEvent];
    
    NSView *view = [self hitTest:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
    
    [self.subviews enumerateObjectsUsingBlock:^(__kindof NSView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        obj.layer.borderColor = GRAY_BORDER_COLOR.CGColor;
        
    }];
    
    view.layer.borderColor = BLUE_UI_COLOR.CGColor;
}

-(void)mouseUp:(NSEvent *)theEvent {
    [super mouseUp:theEvent];
    
    NSView *view = [self hitTest:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
    
    
    NSUInteger index = [self.subviews indexOfObject:view];
    
    
     TGGifSearchRowItem *item = (TGGifSearchRowItem *)[self rowItem];
    
    if(index < item.gifs.count) {
        [item.table.tm_delegate selectionDidChange:index item:item];
    }
    
}

-(void)mouseDown:(NSEvent *)theEvent {
    
}

@end


@interface TGModalGifSearch () <TMSearchTextFieldDelegate,TMTableViewDelegate> {
    __block SMDelayedBlockHandle _delayedBlockHandle;
}
@property (nonatomic,strong) TMTableView *tableView;
@property (nonatomic,strong) TMSearchTextField *searchField;

@property (nonatomic,weak) RPCRequest *request;
@end

@implementation TGModalGifSearch

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

-(instancetype)initWithFrame:(NSRect)frameRect {
    if(self = [super initWithFrame:frameRect]) {
        [self setContainerFrameSize:NSMakeSize(300, 300)];
        
        [self initialize];
    }
    
    return self;
}


-(void)initialize {
    _tableView = [[TMTableView alloc] initWithFrame:NSMakeRect(0, 0, self.containerSize.width, self.containerSize.height-50)];
    [self addSubview:_tableView.containerView];
    
    
    _tableView.tm_delegate = self;
    
    _searchField = [[TMSearchTextField alloc] initWithFrame:NSMakeRect(10, self.containerSize.height - 40, self.containerSize.width - 20, 30)];
    _searchField.delegate = self;
    [self addSubview:_searchField];
}

- (CGFloat)rowHeight:(NSUInteger)row item:(TMRowItem *) item {
    return [self size].height;
}
- (BOOL)isGroupRow:(NSUInteger)row item:(TMRowItem *) item {
    return NO;
}
- (TMRowView *)viewForRow:(NSUInteger)row item:(TMRowItem *) item {
    return [_tableView cacheViewForClass:[TGGifSearchRowView class] identifier:@"TGGifSearchRowView" withSize:NSMakeSize(self.containerSize.width, self.size.height)];
}
- (void)selectionDidChange:(NSInteger)row item:(TGGifSearchRowItem *) item {
    
    TLFoundGif *gif = item.gifs[row];
    
    
    [self close:YES];
    
    __block TLDocument *document = gif.document;
    __block TLWebPage *webpage = nil;
    dispatch_block_t execute = ^{
        
        if(document == nil) {
            
            NSMutableArray *attrs = [[NSMutableArray alloc] init];
            
            [attrs addObject:[TL_documentAttributeImageSize createWithW:gif.w h:gif.h]];
            
            TGGifSearchRowView *view = [_tableView viewAtColumn:0 row:[_tableView indexOfItem:item] makeIfNecessary:NO];
            
            NSImageView *imageView = view.subviews[row];
            
            
            
            NSSize thumbSize = strongsize(NSMakeSize(gif.w, gif.h), 90);
            document = [TL_externalDocument createWithN_id:webpage.n_id date:[[MTNetwork instance] getTime] mime_type:@"image/gif" thumb:[TL_photoCachedSize createWithType:@"x" location:[TL_fileLocationUnavailable createWithVolume_id:0 local_id:0 secret:0] w:thumbSize.width h:thumbSize.height bytes:jpegNormalizedData(imageView.image)] external_url:gif.url search_q:self.searchField.stringValue perform_date:webpage.date external_webpage:webpage attributes:attrs];
        }
        
        TLMessageMedia *media = [TL_messageMediaDocument createWithDocument:document];
        
        [self.messagesViewController sendFoundGif:media forConversation:self.messagesViewController.conversation];
    };
    
    
    if(!document) {
        
        [TMViewController showModalProgress];
        
        [RPCRequest sendRequest:[TLAPI_messages_getWebPagePreview createWithMessage:gif.url] successHandler:^(id request, TL_messageMediaWebPage * response) {
            
            if(![response.webpage isKindOfClass:[TL_webPageEmpty class]]) {
                
                if([response.webpage isKindOfClass:[TL_webPagePending class]] || ([response.webpage isKindOfClass:[TL_webPage class]] && response.webpage.document != nil)) {
                    webpage = response.webpage;
                    document = webpage.document;
                    
                    execute();
                    [TMViewController hideModalProgressWithSuccess];
                }
                
            }
            
            [TMViewController hideModalProgress];
            
        } errorHandler:^(id request, RpcError *error) {
            [TMViewController hideModalProgress];
        }];
    } else {
        execute();
    }
    
    
    
}
- (BOOL)selectionWillChange:(NSInteger)row item:(TMRowItem *) item {
    return NO;
}
- (BOOL)isSelectable:(NSInteger)row item:(TMRowItem *) item {
    return NO;
}


-(void)searchFieldTextChange:(NSString *)searchString {
    
    cancel_delayed_block(_delayedBlockHandle);
    
    [_request cancelRequest];
    
    _delayedBlockHandle = perform_block_after_delay(0.5, ^{
        _request = [RPCRequest sendRequest:[TLAPI_messages_searchGifs createWithQ:searchString offset:0] successHandler:^(id request, TL_messages_foundGifs *response) {
            
            [self drawResponse:response.results];
            
        } errorHandler:^(id request, RpcError *error) {
            
            
        }];
    });
    
    
}

-(NSSize)size {
    int s = (self.containerSize.width - 20 - 8) / 4;
    return NSMakeSize(s, s);
}

-(void)drawResponse:(NSArray *)gifs {
    [self.tableView removeAllItems:YES];
    
    NSMutableArray *row = [[NSMutableArray alloc] init];
    
    [gifs enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if(row.count < 4) {
            [row addObject:obj];
        } else  {
            TGGifSearchRowItem *item = [[TGGifSearchRowItem alloc] initWithObject:[row copy]];
            [row removeAllObjects];
            [row addObject:obj];
            
            [_tableView addItem:item tableRedraw:NO];
        }
        
    }];
    
    if(row.count > 0) {
        TGGifSearchRowItem *item = [[TGGifSearchRowItem alloc] initWithObject:row];
        [_tableView addItem:item tableRedraw:NO];
    }
    
    [_tableView reloadData];
    
}

@end