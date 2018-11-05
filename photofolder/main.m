// (C)opyright 2018-08-24 Dirk Holtwick, holtwick.it. All rights reserved.

/**

 Beispiele:

 photofolder -v --copy --dry --checksum --dimensions --maker --month-folder --destination=../Bilder3/ -- *
 photofolder -v --smart --destination=../Bilder3/ -- *

 */

@import CommonCrypto;
@import Foundation;
@import Cocoa;

#include <getopt.h>

@implementation NSDate (Stamper)

+ (NSDate *)dateFromString:(NSString *)dateString format:(NSString *)format {
    static NSMutableDictionary *formatterCache;
    @synchronized(self) {
        if(!formatterCache) {
            formatterCache = [[NSMutableDictionary alloc] init];
        }
        NSDateFormatter *dateFormatter = [formatterCache objectForKey:format];
        if (!dateFormatter) {
            dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
            // [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
            [dateFormatter setDateFormat:format];
            [formatterCache setObject:dateFormatter forKey:format];
        }
        return [dateFormatter dateFromString:dateString];
    }
}

- (NSString*)formatDate:(NSString *)formatStr {
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    if(!formatStr) {
        formatter.dateFormat = @"yyyy'-'MM'-'dd' 'HH':'mm':'ss'";
    } else {
        formatter.dateFormat = formatStr;
    }
    id locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    formatter.locale = locale;
    return [formatter stringFromDate:self];
}

@end

NSString *sha1ShortOfFile(NSString *path) {
    FILE* fileHandle = fopen(path.UTF8String, "rb");
    if(fileHandle == NULL) {
        return nil;
    }

    const unsigned int bufferSize = 16384;
    unsigned char buffer[bufferSize];

    CC_SHA1_CTX context;
    CC_SHA1_Init(&context);

    while(YES) {
        //    Read the file in chunks so a file of any size can be digested
        const size_t readSize = fread(buffer, 1, sizeof(buffer), fileHandle);
        CC_SHA1_Update(&context, buffer, (CC_LONG)readSize);
        if(readSize <= 0) {
            break;
        }
    }
    fclose(fileHandle);

    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1_Final(digest, &context);

    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for(int i = 0; i < MIN(3, CC_SHA1_DIGEST_LENGTH); i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    return output;
}

NSDictionary *analyzeImage(NSURL* url) {
    if (nil == url) {
        return nil;
    }

    NSDictionary *props = nil;
    NSDate *exifDate = nil;

    CGImageSourceRef _source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (_source) {
        // get image properties (height, width, depth, metadata etc.) for display
        props = (__bridge_transfer NSDictionary*)CGImageSourceCopyPropertiesAtIndex(_source, 0, NULL);
        // image thumbnail options
        //        NSDictionary* thumbOpts = [NSDictionary dictionaryWithObjectsAndKeys:
        //                                   (id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailWithTransform,
        //                                   (id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailFromImageIfAbsent,
        //                                   [NSNumber numberWithInt:128], (id)kCGImageSourceThumbnailMaxPixelSize,
        //                                   nil];
        // make image thumbnail
        //        CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)thumbOpts);
        //        [mThumbView setImage:image];
        //        CGImageRelease(image);
        // set image path string for image info panel
        //        [mFilePath setStringValue:[mUrl path]];
        // set image type string for image info panel
        //        NSString* uti = (__bridge NSString*)CGImageSourceGetType(source);
        //        [mFileType setStringValue:[NSString stringWithFormat:@"%@\n%@",
        //                                   ImageIOLocalizedString(uti), uti]];
        // set image size string for image info panel
        //        CFDictionaryRef fileProps = CGImageSourceCopyProperties(source, nil);
        //        [mFileSize setStringValue:[NSString stringWithFormat:@"%@ bytes",
        //                                   (__bridge id)CFDictionaryGetValue(fileProps, kCGImagePropertyFileSize)]];
        //        CFRelease(fileProps);

        // EXIF
        id v = [[props objectForKey:(id)kCGImagePropertyExifDictionary] objectForKey:(id)kCGImagePropertyExifDateTimeOriginal];
        if(v) {
            exifDate = [NSDate dateFromString:v format:@"yyyy':'MM':'dd' 'HH':'mm':'ss"];
        }
        // IPTC
        if (!exifDate) {
            v = [[props objectForKey:(id)kCGImagePropertyIPTCDictionary] objectForKey:(id)kCGImagePropertyIPTCDigitalCreationDate];
            if(v) {
                exifDate = [NSDate dateFromString:[NSString stringWithFormat:@"%@ %@", v, [[props objectForKey:(id)kCGImagePropertyIPTCDictionary] objectForKey:(id)kCGImagePropertyIPTCDigitalCreationTime]]
                                           format:@"yyyyMMdd HHmmssZZZZ"];
            }
        }
        // TIFF
        if (!exifDate) {
            v = [[props objectForKey:(id)kCGImagePropertyTIFFDictionary] objectForKey:(id)kCGImagePropertyTIFFDateTime];
            if(v) {
                exifDate = [NSDate dateFromString:v format:@"yyyy:MM:dd HH:mm:ss"];
            }
        }

        CFRelease(_source);
    }

    id markerString = @"";
    id m1 = [props[(id)kCGImagePropertyTIFFDictionary][(id)kCGImagePropertyTIFFMake] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    id m2 = [props[(id)kCGImagePropertyTIFFDictionary][(id)kCGImagePropertyTIFFModel] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([m1 length]) {
        markerString = [m1 componentsSeparatedByString:@" "][0];
        if ([m2 length]) {
            if ([[markerString lowercaseString] isEqualToString:[[m2 componentsSeparatedByString:@" "][0] lowercaseString]]) {
                markerString = m2;
            }
            else {
                markerString = [NSString stringWithFormat:@"%@ %@", markerString, m2];
            }
        }
    }
    else if ([m2 length]) {
        markerString = m2;
    }

    // NSAssert(props != nil, @"Where is the props gone?");

    NSDate *date = exifDate;
    if (!date) {
        NSDate *creationDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:[url path] error:NULL] fileModificationDate];
        NSDate *modificationDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:[url path] error:NULL] fileCreationDate];
        if (creationDate && modificationDate) {
            date = [creationDate isLessThan:modificationDate] ? creationDate : modificationDate;
        } else {
            date = creationDate ?: modificationDate;
        }
    }

    return @{
             @"date": date ?: [NSNull null],
             @"width": props[(id)kCGImagePropertyPixelWidth] ?: [NSNull null],
             @"height": props[(id)kCGImagePropertyPixelHeight] ?: [NSNull null],
             @"dim": ((props[(id)kCGImagePropertyPixelWidth] != nil && [props[(id)kCGImagePropertyPixelWidth] integerValue] > 0) ?
                      [NSString stringWithFormat:@"%@x%@", props[(id)kCGImagePropertyPixelWidth], props[(id)kCGImagePropertyPixelHeight]]
                      : @""),
             @"maker": [markerString length] ? [NSString stringWithFormat:@" %@", markerString] : @"",
             @"props": props ?: [NSNull null]
             };
}

int optVerbose = 0;
int optRecursive = 0;
int optDry = 0;
int optChecksum = 0;
int optSize = 0;
int optDimensions = 0;
int optHEIC = 0;
int optYearFolder = 0;
int optMonthFolder = 0;
int optMaker = 0;
int optCopy = 0;
int optVersion = 0;
int optSmartCopy = 0;
int optSmartMove = 0;
int optProgress = 0;
int optHelp = 0;

static struct option longOpts[] = {
    { "verbose",       no_argument,           NULL,             'v' },
    { "recursive",     no_argument,           NULL,             'r' },
    { "copy",          no_argument,           NULL,             'c' },
    { "destination",   required_argument,     NULL,             'o' },
    { "name",          required_argument,     NULL,             'n' },
    { "min-width",     required_argument,     NULL,             'w' },
    { "min-height",    required_argument,     NULL,             'h' },
    { "days",          required_argument,     NULL,             's' },
    { "dry",           no_argument,           NULL,             'd' },
    { "progress",      no_argument,           NULL,             'p' },
    { "help",          no_argument,           NULL,             '?' },
    { "checksum",      no_argument,           &optChecksum,     1 },
    { "dimensions",    no_argument,           &optDimensions,   1 },
    { "year-folder",   no_argument,           &optYearFolder,   1 },
    { "month-folder",  no_argument,           &optMonthFolder,  1 },
    { "maker",         no_argument,           &optMaker,        1 },
    { "smart-copy",    no_argument,           &optSmartCopy,    1 },
    { "smart-move",    no_argument,           &optSmartMove,    1 },
    { "heic",          no_argument,           &optHEIC,         1 },
    { "version",       no_argument,           &optVersion,      1 },
    { "size",          no_argument,           &optSize,         1 },
    { NULL,            0,                     NULL,             0 }
};

void print_usage(char *name) {
    fprintf (stderr,
             "\nUsage: %s <options> [inputfile ...]\n\n",
             [[[NSString stringWithUTF8String:name] lastPathComponent] UTF8String]);
    fprintf (stderr,
             "  -?  --help                 Display this usage information.\n"
             "  -v  --verbose              Print verbose messages.\n"
             "  -r  --recursive            Recurse into input folders.\n"
             "  -o  --destination=folder   Target folder.\n"
             "  -n  --name=text            Add name to file name.\n"
             "  -c  --copy                 Copy instead of move.\n"
             "  -p  --progress             Show progress.\n"
             //             "  -w  --min-width=px         Minimal image width in pixels.\n"
             //             "  -h  --min-height=px        Minimal image height in pixels.\n"
             "  -s  --days=number          Maximal age in days.\n"
             "      --dry                  Dry run.\n"
             "      --checksum             Identify duplicates by SHA1 of content.\n"
             "      --size                 Identify duplicates by file size in bytes.\n"
             "      --dimensions           Add dimensions to file name.\n"
             "      --maker                Add maker/ camera model to file name.\n"
             "      --year-folder          Subfolders per year.\n"
             "      --month-folder         Subfolders per year and month.\n"
             "      --heic                 Convert HEIC to JPG and minimize size.\n"
             // "      --optimize             Convert to JPG and minimize size.\n"
             "      --smart-copy           Most options for unique incremental copy.\n"
             "      --smart-move           Most options for unique incremental move.\n"
             "      --version              Version info.\n"
             "\n"
             );
}

int command(int argc, char * argv[]) {
    char ch;
    id destFolderName = nil;
    NSDate *sinceDate = nil;
    id insertName = @"";


    // the colon : indicates that an argument is required!
    // do not forget to repeat short chars here again!
    while ((ch = getopt_long(argc, argv, "vrco:s:n:w:h:dp?", longOpts, NULL)) != -1) {
        switch (ch) {
            case 'v': {
                optVerbose = 1;
                break;
            }
            case 'r': {
                optRecursive = 1;
                break;
            }
            case 'c': {
                optCopy = 1;
                break;
            }
            case 'p': {
                optProgress = 1;
                break;
            }
            case 'o': {
                // printf("Dest arg %s", optarg);
                destFolderName = optarg ? [NSString stringWithUTF8String:optarg] : nil;
                break;
            }
            case 's': {
                // printf("Dest arg %s", optarg);
                NSString *daysString = optarg ? [NSString stringWithUTF8String:optarg] : nil;
                if (daysString) {
                    NSInteger days = daysString.integerValue;
                    if (days > 0) {
                        sinceDate = [[NSDate alloc] initWithTimeIntervalSinceNow:-86400 * days];
                    }
                }
                if (!sinceDate) {
                    puts([NSString stringWithFormat:@"Wrong value for --days argument: %@\n", daysString].UTF8String);
                    return -1;
                }
                puts([NSString stringWithFormat:@"Only images newer than %@\n", sinceDate].UTF8String);
                break;
            }
            case 'd': {
                optDry = 1;
                break;
            }
            case 'n': {
                insertName = optarg ? [NSString stringWithFormat:@" %@", [NSString stringWithUTF8String:optarg]] : @"";
                break;
            }
            case 'w': {
                //                insertName = optarg ? [NSString stringWithFormat:@" %@", [NSString stringWithUTF8String:optarg]] : @"";
                break;
            }
            case 'h': {
                //                insertName = optarg ? [NSString stringWithFormat:@" %@", [NSString stringWithUTF8String:optarg]] : @"";
                break;
            }
            case 0: {
                // Long options
                break;
            }
            case '?': {
                optHelp = 1;
                break;
            }
            default: {
                // Error
                abort();
            }
        }
    }

    if (optHelp || argc <= 1) {
        print_usage(argv[0]);
        exit(1);
    }

    if (optVersion) {
        printf("Version " __DATE__ "\n");
        exit(0);
    }

    if (optSmartCopy || optSmartMove) {
        optYearFolder = 1;
        optMonthFolder = 1;
        optMaker = 1;
        optCopy = optSmartCopy;
        optRecursive = 1;
        //        optChecksum = 0;
        //        optSize = 0;
        optDimensions = 0;
    }

    optYearFolder = optYearFolder || optMonthFolder;

    if (optYearFolder && !destFolderName) {
        printf("--destination required\n");
        return 0;
    }

    NSUInteger numberOfFiles = 0;
    NSUInteger numberOfMovedOrCopiedFiles = 0;
    NSUInteger numberOfSkippedFiles = 0;

    // Files
    argc -= optind;
    argv += optind;

    // Move to folder without preserving subfolder structure
    //        NSLog(@"Destination folder: %@ %@", destFolderName, fileNames);
    if (destFolderName) {
        destFolderName = [destFolderName stringByStandardizingPath];

        if (optVerbose) {
            printf("Destination path: %s\n", [destFolderName UTF8String]);
        }

        BOOL isDir = NO;
        BOOL isFile = [[NSFileManager defaultManager] fileExistsAtPath:destFolderName isDirectory:&isDir];

        if (isFile && !isDir) {
            printf("Destination path is an existing file: %s", [destFolderName UTF8String]);
            return 0;
        }

        if (!isFile && !isDir && !optDry) {
            [[NSFileManager defaultManager] createDirectoryAtPath:destFolderName
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:NULL];
        }
    }

    // Input files and dirs
    id fileNames = [NSMutableSet set];

    for (int i = 0; i < argc; ++i) {
        NSString *fileName = [NSString stringWithUTF8String:argv[i]];

        BOOL isDir = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:fileName isDirectory:&isDir];

        if (optVerbose) {
            printf("Collect path: %s | is dir: %d\n", [fileName UTF8String], isDir);
        }

        if (!isDir) {
            [fileNames addObject:fileName];
        }

        else if (optRecursive) {
            NSString *subFileName;
            NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:fileName];
            while ((subFileName = [enumerator nextObject])) {
                subFileName = [fileName stringByAppendingPathComponent:subFileName];
                if (optVerbose) {
                    printf("Collect path: %s\n", [subFileName UTF8String]);
                }
                [fileNames addObject:subFileName];
            }
        }
    }

    // Sorted
    fileNames = [[fileNames allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

    // For progress
    NSUInteger filesTotal = [fileNames count], filesVisited = 0;
    optProgress = optProgress && !optDry && !optVerbose;

    // Flush immediately
    //    if (optProgress) {
    //        setbuf(stdout, NULL);
    //    }

    // Iterate over the rest, the shell adds support for patterns
    for(NSString *name in fileNames) {

        // Progress
        if (optProgress && filesVisited > 0 && filesVisited % 25 == 0) {
            printf("\r%lu%% | %lu of %lu files ",
                   filesVisited * 100 / filesTotal,
                   filesVisited,
                   filesTotal);
            fflush(stdout);
        }
        ++filesVisited;

        // Skip hidden files
        if ([[name lastPathComponent] hasPrefix:@"."]) {
            continue;
        }

        BOOL isDir = NO;
        BOOL isFile = [[NSFileManager defaultManager] fileExistsAtPath:name isDirectory:&isDir];
        isFile = isFile && !isDir;

        //            printf("-> %s\n", [name UTF8String]);

        //            id files = @[name];
        //            if (isDir) {
        //                NSLog(@"Look into folder %@", name);
        //            }

        if (isFile) {
            ++numberOfFiles;

            id url = [NSURL fileURLWithPath:name];
            id info = analyzeImage(url);
            //                if (optVerbose) {
            //                    NSLog(@"Testing file %@ %@", name, info);
            //                }

            id dimString = optDimensions ? info[@"dim"] : @"";
            if ([dimString length]) {
                dimString = [NSString stringWithFormat:@" %@", dimString];
            }

            id makerName = optMaker ? info[@"maker"] : @"";

            id checksumOrSize = @"";
            if (optSize) {
                checksumOrSize = [NSString stringWithFormat:@" %@", [[NSFileManager defaultManager] attributesOfItemAtPath:[url path] error:NULL][NSFileSize]];
            }
            else if (optChecksum) {
                checksumOrSize = [NSString stringWithFormat:@" %@", sha1ShortOfFile(name)];
            }

            NSDate *date = info[@"date"];

            if (sinceDate) {
                if (!date || [sinceDate timeIntervalSinceDate:date] > 0) {
                    if (optVerbose || optDry) {
                        printf("Skip old: %s\n", [name UTF8String]);
                    }
                    ++numberOfSkippedFiles;
                    continue;
                }
            }

            if (date) {
                NSString *body = [NSString stringWithFormat:@"%@%@%@%@%@",
                                  [date formatDate:@"yyyy'-'MM'-'dd' 'HH'-'mm'-'ss'"],
                                  checksumOrSize,
                                  dimString,
                                  makerName,
                                  insertName
                                  ];

                if (optYearFolder) {
                    id path = nil;
                    id yearString = [date formatDate:@"yyyy"];
                    if (optMonthFolder) {
                        id monthString = [date formatDate:@"MM"];
                        yearString = [yearString stringByAppendingPathComponent:monthString];
                    }
                    if ([destFolderName length]) {
                        path = [destFolderName stringByAppendingPathComponent:yearString];
                    }
                    else {
                        path = yearString;
                    }
                    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
                        if (optVerbose) {
                            printf("Create destination folder: %s\n", [path UTF8String]);
                        }
                        if (!optDry) {
                            [[NSFileManager defaultManager] createDirectoryAtPath:path
                                                      withIntermediateDirectories:YES
                                                                       attributes:nil
                                                                            error:NULL];
                        }
                    }
                    body = [path stringByAppendingPathComponent:body];
                }
                else if ([destFolderName length]) {
                    body = [destFolderName stringByAppendingPathComponent:body];
                }

                NSInteger ct = 1;
                NSString *altName = [NSString stringWithFormat:@"%@.%@",
                                     body,
                                     [[name pathExtension] lowercaseString]];


                if (!name || !altName || [name isEqualToString:altName]) {
                    if (optVerbose || optDry) {
                        printf("Skip unchanged: %s\n", [name UTF8String]);
                    }
                    ++numberOfSkippedFiles;
                    continue;
                }

                if ((optChecksum || optSize) && [[NSFileManager defaultManager] fileExistsAtPath:altName isDirectory:&isDir]) {
                    if (optVerbose || optDry) {
                        printf("Skip duplicate: %s\n", [name UTF8String]);
                    }
                    ++numberOfSkippedFiles;
                    continue;
                }

                while ([[NSFileManager defaultManager] fileExistsAtPath:altName isDirectory:&isDir]) {
                    altName = [NSString stringWithFormat:@"%@ %@.%@",
                               body,
                               @(ct++),
                               [[name pathExtension] lowercaseString]];
                }

                if (name && altName) {
                    ++numberOfMovedOrCopiedFiles;
                    if (optCopy) {
                        if (optVerbose || optDry) {
                            printf("Copy: %s => %s\n", [name UTF8String], [altName UTF8String]);
                        }
                        if (!optDry) {

                            NSLog(@"heic %@ name %@", @(optHEIC), name);
                            if (optHEIC && [[[name pathExtension] lowercaseString] isEqualToString:@"heic"]) {
                                NSImage *image = [[NSImage alloc] initWithContentsOfFile:name];
                                CGImageSourceRef imgSrc = CGImageSourceCreateWithData((CFDataRef)image.TIFFRepresentation, NULL);
                                CGImageRef img = CGImageSourceCreateImageAtIndex(imgSrc, 0, NULL);
                                CFRelease(imgSrc);
                                CFAutorelease(img);
                                NSBitmapImageRep *bitmapImageRep = [[NSBitmapImageRep alloc] initWithCGImage:img];
                                NSData *data = [bitmapImageRep representationUsingType:NSJPEGFileType properties:@{NSImageCompressionFactor:@0.95}];
                                NSLog(@"heic %@ name %@", @(optHEIC), name);
                                altName = [[altName stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"];
                                [data writeToFile:altName atomically:YES];
                            } else {
                                [[NSFileManager defaultManager] copyItemAtPath:name
                                                                        toPath:altName
                                                                         error:NULL];
                            }
                        }
                    }
                    else {
                        if (optVerbose || optDry) {
                            printf("Move: %s => %s\n", [name UTF8String], [altName UTF8String]);
                        }
                        if (!optDry) {
                            [[NSFileManager defaultManager] moveItemAtPath:name
                                                                    toPath:altName
                                                                     error:NULL];
                        }
                    }

                    // jpegoptim -p /Users/dirk/Desktop/IMG_20140902_093942\ copy\ 2.jpg -v --strip-iptc --strip-icc -m75
                }
            }
        }
    }

    if (optProgress) {
        printf("\r                                                         \r");
    }

    printf("%lu files, %lu %s, %lu skipped.\n",
           (unsigned long)numberOfFiles,
           numberOfMovedOrCopiedFiles,
           optCopy ? "copied" : "moved",
           numberOfSkippedFiles
           );

    return 0;
}

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return command(argc, argv);
    }
    return 0;
}
