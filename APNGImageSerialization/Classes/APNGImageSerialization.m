// APNGImageSerialization.h
//
// Copyright (c) 2016 Ricky Tan
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "APNGImageSerialization.h"

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_9_0
#define kCGImagePropertyAPNGDelayTime           CFSTR("DelayTime")
#define kCGImagePropertyAPNGLoopCount           CFSTR("LoopCount")
#define kCGImagePropertyAPNGUnclampedDelayTime  CFSTR("UnclampedDelayTime")
#endif

NSString * const APNGImageErrorDomain = @"APNGImageErrorDomain";


__attribute((overloadable)) UIImage * UIAnimatedImageWithAPNGData(NSData *data)
{
    return UIAnimatedImageWithAPNGData(data, 0.f);
}

__attribute((overloadable)) UIImage * UIAnimatedImageWithAPNGData(NSData *data, NSTimeInterval duration)
{
    return UIAnimatedImageWithAPNGData(data, duration, 0.f, NULL);
}

__attribute((overloadable)) UIImage * UIAnimatedImageWithAPNGData(NSData *data, NSTimeInterval duration, CGFloat scale, NSError * __autoreleasing * error)
{
    NSDictionary *userInfo = nil;
    UIImage *resultImage = nil;
    
    do {
        if (!data.length) {
            userInfo = @{NSLocalizedDescriptionKey: @"Data is empty"};
            break;
        }
        
        CGImageSourceRef sourceRef = CGImageSourceCreateWithData((CFDataRef)data, nil);
        CGImageSourceStatus status = CGImageSourceGetStatus(sourceRef);
        if (status != kCGImageStatusComplete && status != kCGImageStatusIncomplete && status != kCGImageStatusReadingHeader) {
            switch (status) {
                case kCGImageStatusUnexpectedEOF: {
                    userInfo = @{NSLocalizedDescriptionKey: @"Unexpected end of file"};
                    break;
                }
                case kCGImageStatusInvalidData: {
                    userInfo = @{NSLocalizedDescriptionKey: @"Invalide data"};
                    break;
                }
                case kCGImageStatusUnknownType: {
                    userInfo = @{NSLocalizedDescriptionKey: @"Unknown type"};
                    break;
                }
                default:
                    break;
            }
            break;
        }
        
        
        size_t frameCount = CGImageSourceGetCount(sourceRef);
        if (frameCount <= 1) {
            resultImage = [[UIImage alloc] initWithData:data];
        }
        else {
            NSTimeInterval imageDuration = 0.f;
            NSMutableArray *frames = [NSMutableArray arrayWithCapacity:frameCount];
            
            for (size_t i = 0; i < frameCount; ++i) {
                CGImageRef imageRef = CGImageSourceCreateImageAtIndex(sourceRef, i, nil);
                if (!imageRef) {
                    continue;
                }
                
                NSDictionary *frameProperty = (__bridge NSDictionary *)CGImageSourceCopyPropertiesAtIndex(sourceRef, i, nil);
                NSDictionary *apngProperty = frameProperty[(__bridge NSString *)kCGImagePropertyPNGDictionary];
                NSNumber *delayTime = apngProperty[(__bridge NSString *)kCGImagePropertyAPNGUnclampedDelayTime];
                
                if (delayTime) {
                    imageDuration += [delayTime doubleValue];
                }
                else {
                    delayTime = apngProperty[(__bridge NSString *)kCGImagePropertyAPNGDelayTime];
                    if (delayTime) {
                        imageDuration += [delayTime doubleValue];
                    }
                }
                UIImage *image = [UIImage imageWithCGImage:imageRef
                                                     scale:scale > 0.f ? scale : [UIScreen mainScreen].scale
                                               orientation:UIImageOrientationUp];
                [frames addObject:image];
                
                CFRelease(imageRef);
            }
            
            if (duration > CGFLOAT_MIN) {
                imageDuration = duration;
            }
            else if (imageDuration < CGFLOAT_MIN) {
                imageDuration = 0.1 * frameCount;
            }
            
            resultImage = [UIImage animatedImageWithImages:frames.copy
                                                  duration:imageDuration];
        }
        
        CFRelease(sourceRef);
        
        return resultImage;
    } while (0);
    
    
    if (error) {
        *error = [NSError errorWithDomain:APNGImageErrorDomain
                                     code:APNGErrorCodeNoEnoughData
                                 userInfo:userInfo];
    }
    
    return resultImage;
}

static NSString *APNGImageNameOfScale(NSString *name, CGFloat scale) {
    int ratio = (int)scale;
    if (scale > 1) {
        return [NSString stringWithFormat:@"%@@%dx", name.stringByDeletingPathExtension, ratio];
    }
    return name.stringByDeletingPathExtension;
}

@implementation UIImage (Animated_PNG)

+ (UIImage *)animatedImageNamed:(NSString *)name
{
    CGFloat scale = [UIScreen mainScreen].scale;
    NSString *extension = name.pathExtension;
    if (!extension.length) {
        extension = @"png";
    }
    NSString *path = [[NSBundle mainBundle] pathForResource:APNGImageNameOfScale(name, scale)
                                                     ofType:extension];
    while (!path && scale > 0.f) {
        scale -= 1.f;
        path = [[NSBundle mainBundle] pathForResource:APNGImageNameOfScale(name, scale)
                                               ofType:extension];
    }
    if (path) {
        NSData *data = [NSData dataWithContentsOfFile:path];
        return UIAnimatedImageWithAPNGData(data, 0.f, scale, NULL);
    }
    return nil;
}

+ (UIImage *)apng_animatedImageWithAPNGData:(NSData *)data
{
    return UIAnimatedImageWithAPNGData(data);
}

+ (UIImage *)apng_animatedImageWithAPNGData:(NSData *)data scale:(CGFloat)scale
{
    return UIAnimatedImageWithAPNGData(data, 0.f, scale, NULL);
}


+ (UIImage *)apng_animatedImageWithAPNGData:(NSData *)data duration:(NSTimeInterval)duration
{
    return UIAnimatedImageWithAPNGData(data, duration);
}

+ (UIImage *)apng_animatedImageWithAPNGData:(NSData *)data
                                   duration:(NSTimeInterval)duration
                                      scale:(CGFloat)scale
{
    return UIAnimatedImageWithAPNGData(data, duration, scale, NULL);
}

@end

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_9_0
#undef kCGImagePropertyAPNGDelayTime
#undef kCGImagePropertyAPNGLoopCount
#undef kCGImagePropertyAPNGUnclampedDelayTime
#endif
