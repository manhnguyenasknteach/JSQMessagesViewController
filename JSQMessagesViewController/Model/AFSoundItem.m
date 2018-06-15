//
//  AFSoundItem.m
//  AFSoundManager-Demo
//
//  Created by Alvaro Franco on 20/01/15.
//  Copyright (c) 2015 AlvaroFranco. All rights reserved.
//

#import "AFSoundItem.h"
#import "AFSoundManager.h"

@implementation AFSoundItem

-(id)initWithLocalResource:(NSString *)path {
    
    if (self == [super init]) {
        
        _type = AFSoundItemTypeLocal;
        
        _URL = [NSURL fileURLWithPath:path];
        
        [self fetchMetadata];
    }
    
    return self;
}

-(id)initWithStreamingURL:(NSURL *)URL {
    
    if (self == [super init]) {
        
        _type = AFSoundItemTypeStreaming;
        
        _URL = URL;
        
        [self fetchMetadata];
    }
    
    return self;
}

-(void)fetchMetadata {
    
    AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithURL:_URL];
    
    NSArray *metadata = [playerItem.asset commonMetadata];
    
    for (AVMetadataItem *metadataItem in metadata) {
        
        [metadataItem loadValuesAsynchronouslyForKeys:@[AVMetadataKeySpaceCommon] completionHandler:^{
            
            if ([metadataItem.commonKey isEqualToString:@"title"]) {
                
                _title = (NSString *)metadataItem.value;
            } else if ([metadataItem.commonKey isEqualToString:@"albumName"]) {
                
                _album = (NSString *)metadataItem.value;
            } else if ([metadataItem.commonKey isEqualToString:@"artist"]) {
                
                _artist = (NSString *)metadataItem.value;
            } else if ([metadataItem.commonKey isEqualToString:@"artwork"]) {
                
                if ([metadataItem.keySpace isEqualToString:AVMetadataKeySpaceID3]) {
                    
                    _artwork = [UIImage imageWithData:[[metadataItem.value copyWithZone:nil] objectForKey:@"data"]];
                } else if ([metadataItem.keySpace isEqualToString:AVMetadataKeySpaceiTunes]) {
                    
                    _artwork = [UIImage imageWithData:[metadataItem.value copyWithZone:nil]];
                }
            }
        }];
    }
}

-(void)setInfoFromItem:(AVPlayerItem *)item {
    
    _duration = CMTimeGetSeconds(item.duration);
    _timePlayed = CMTimeGetSeconds(item.currentTime);
}

@end
