#import "ViewController.h"
#import <CommonCrypto/CommonDigest.h>
#import "archive.h"
#import "archive_entry.h"
#import <sys/utsname.h>

NSString *__NSTemporaryDirectory(void)
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/usr/sbin/mediaserverd"])
    {
        return @"/private/var/tmp/";
    }
    
    return NSTemporaryDirectory();
}


@implementation ViewController

- (NSString *)deviceModel {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.selectedPaths = [NSMutableSet new];
    self.selectedForSharing = [NSMutableSet new];
    self.currentContents = [NSMutableArray new];
    self.operationQueue = [[NSOperationQueue alloc] init];
    
    // Initialize model name mapping - includes models later than iOS 14
    self.modelNameMap = @{
        @"iPhone1,1": @"iPhone",
        @"iPhone1,2": @"iPhone_3G",
        @"iPhone2,1": @"iPhone_3GS",
        @"iPhone3,1": @"iPhone_4",
        @"iPhone3,2": @"iPhone_4_GSM_Rev_A",
        @"iPhone3,3": @"iPhone_4_CDMA",
        @"iPhone4,1": @"iPhone_4S",
        @"iPhone5,1": @"iPhone_5_GSM",
        @"iPhone5,2": @"iPhone_5_GSMCDMA",
        @"iPhone5,3": @"iPhone_5C_GSM",
        @"iPhone5,4": @"iPhone_5C_Global",
        @"iPhone6,1": @"iPhone_5S_GSM",
        @"iPhone6,2": @"iPhone_5S_Global",
        @"iPhone7,1": @"iPhone_6_Plus",
        @"iPhone7,2": @"iPhone_6",
        @"iPhone8,1": @"iPhone_6s",
        @"iPhone8,2": @"iPhone_6s_Plus",
        @"iPhone8,4": @"iPhone_SE_GSM",
        @"iPhone9,1": @"iPhone_7",
        @"iPhone9,2": @"iPhone_7_Plus",
        @"iPhone9,3": @"iPhone_7",
        @"iPhone9,4": @"iPhone_7_Plus",
        @"iPhone10,1": @"iPhone_8",
        @"iPhone10,2": @"iPhone_8_Plus",
        @"iPhone10,3": @"iPhone_X_Global",
        @"iPhone10,4": @"iPhone_8",
        @"iPhone10,5": @"iPhone_8_Plus",
        @"iPhone10,6": @"iPhone_X_GSM",
        @"iPhone11,2": @"iPhone_XS",
        @"iPhone11,4": @"iPhone_XS_Max",
        @"iPhone11,6": @"iPhone_XS_Max_Global",
        @"iPhone11,8": @"iPhone_XR",
        @"iPhone12,1": @"iPhone_11",
        @"iPhone12,3": @"iPhone_11_Pro",
        @"iPhone12,5": @"iPhone_11_Pro_Max",
        @"iPhone12,8": @"iPhone_SE_2nd_Gen",
        @"iPhone13,1": @"iPhone_12_Mini",
        @"iPhone13,2": @"iPhone_12",
        @"iPhone13,3": @"iPhone_12_Pro",
        @"iPhone13,4": @"iPhone_12_Pro_Max",
        @"iPhone14,2": @"iPhone_13_Pro",
        @"iPhone14,3": @"iPhone_13_Pro_Max",
        @"iPhone14,4": @"iPhone_13_Mini",
        @"iPhone14,5": @"iPhone_13",
        @"iPhone14,6": @"iPhone_SE_3rd_Gen",
        @"iPhone14,7": @"iPhone_14",
        @"iPhone14,8": @"iPhone_14_Plus",
        @"iPhone15,2": @"iPhone_14_Pro",
        @"iPhone15,3": @"iPhone_14_Pro_Max",
        @"iPhone15,4": @"iPhone_15",
        @"iPhone15,5": @"iPhone_15_Plus",
        @"iPhone16,1": @"iPhone_15_Pro",
        @"iPhone16,2": @"iPhone_15_Pro_Max",
        @"iPhone17,1": @"iPhone_16_Pro",
        @"iPhone17,2": @"iPhone_16_Pro_Max",
        @"iPhone17,3": @"iPhone_16",
        @"iPhone17,4": @"iPhone_16_Plus"
    };
    
    [self setupUI];
    [self navigateToPath:NSHomeDirectory()];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.currentContents.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FileCell" forIndexPath:indexPath];
    
    NSString *filename = self.currentContents[indexPath.row];
    NSString *fullPath = [filename isEqualToString:@".."] ?
                        [self.currentPath stringByDeletingLastPathComponent] :
                        [self.currentPath stringByAppendingPathComponent:filename];
    
    // Share button
    UIButton *shareButton = [UIButton buttonWithType:UIButtonTypeSystem];
    shareButton.frame = CGRectMake(0, 0, 44, 44);
    [shareButton setImage:[UIImage systemImageNamed:@"square.and.arrow.up"] forState:UIControlStateNormal];
    shareButton.tag = indexPath.row;
    [shareButton addTarget:self action:@selector(shareButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    cell.accessoryView = shareButton;
    
    if ([filename isEqualToString:@".."]) {
        cell.textLabel.text = @"..";
        cell.imageView.image = [UIImage systemImageNamed:@"folder.fill"];
        cell.imageView.tintColor = [UIColor systemBlueColor];
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        BOOL isDirectory;
        [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
        
        cell.textLabel.text = filename;
        
        if (isDirectory) {
            cell.imageView.image = [UIImage systemImageNamed:@"folder.fill"];
            cell.imageView.tintColor = [UIColor systemBlueColor];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.imageView.image = [UIImage systemImageNamed:@"doc"];
            cell.imageView.tintColor = [UIColor systemGrayColor];
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    cell.backgroundColor = [self.selectedPaths containsObject:fullPath] ?
                          [UIColor systemGray3Color] :
                          [UIColor clearColor];
    
    return cell;
}

- (void)shareButtonTapped:(UIButton *)sender {
    NSString *filename = self.currentContents[sender.tag];
    NSString *fullPath = [self.currentPath stringByAppendingPathComponent:filename];
    
    // If files are selected, share all selected files
    NSMutableSet *pathsToShare = [NSMutableSet new];
    if (self.selectedPaths.count > 0) {
        [pathsToShare addObjectsFromArray:[self.selectedPaths allObjects]];
    } else {
        [pathsToShare addObject:fullPath];
    }
    
    // Create archive
    NSString *archiveName = [self getFormattedFilename:@"files" extension:@"tar.gz"];
    NSString *tempArchivePath = [__NSTemporaryDirectory() stringByAppendingPathComponent:archiveName];
    
    [self showProgressAlert:@"Creating Archive" message:@"Please wait..."];
    self.isCancelled = NO;
    
    [self.operationQueue addOperationWithBlock:^{
        struct archive *a = archive_write_new();
        archive_write_add_filter_gzip(a);
        archive_write_set_format_pax_restricted(a);
        archive_write_open_filename(a, [tempArchivePath UTF8String]);
        
        BOOL success = YES;
        for (NSString *path in pathsToShare) {
            if (self.isCancelled) {
                success = NO;
                break;
            }
            
            if (strncmp(path.UTF8String, "/dev", 4) == 0)
                continue;
            
            const char overprovisioning_path[] = "/var/.overprovisioning_file";
            if (strncmp(path.UTF8String, "/var/.overprovisioning_file", sizeof(overprovisioning_path)-1) == 0)
                continue;
            
            BOOL isDirectory;
            [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
            
            if (isDirectory) {
                success &= [self addDirectoryToArchive:a path:path];
            } else {
                success &= [self addFileToArchive:a path:path];
            }
        }
        
        archive_write_close(a);
        archive_write_free(a);
        
        if (success && !self.isCancelled) {
            NSString *base = @"/var/mobile/Library/Logs/CrashReporter";
            NSString *newPath = [base stringByAppendingPathComponent:archiveName];
            
            rename(tempArchivePath.UTF8String, newPath.UTF8String);
            chmod(newPath.UTF8String, S_IRWXG | S_IRWXO | S_IRWXU);
            sync();
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.progressAlert dismissViewControllerAnimated:YES completion:^{
                    // Share the archive
                    NSURL *archiveURL = [NSURL fileURLWithPath:newPath];
                    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
                                                          initWithActivityItems:@[archiveURL]
                                                          applicationActivities:nil];
                    
                    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                        activityVC.popoverPresentationController.sourceView = sender;
                        activityVC.popoverPresentationController.sourceRect = sender.bounds;
                    }
                    
                    [self presentViewController:activityVC animated:YES completion:nil];
                }];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.progressAlert dismissViewControllerAnimated:YES completion:^{
                    [self showAlert:@"Error" message:@"Failed to create archive"];
                }];
            });
        }
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *selectedItem = self.currentContents[indexPath.row];
    if ([selectedItem isEqualToString:@".."]) {
        [self navigateToPath:[self.currentPath stringByDeletingLastPathComponent]];
        return;
    }
    
    NSString *fullPath = [self.currentPath stringByAppendingPathComponent:selectedItem];
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
    
    if ([self.selectedPaths containsObject:fullPath]) {
        if (isDirectory) {
            [self navigateToPath:fullPath];
        } else {
            [self.selectedPaths removeObject:fullPath];
            [tableView reloadData];
        }
    } else {
        [self.selectedPaths addObject:fullPath];
        [tableView reloadData];
    }
}

- (void)navigateToPath:(NSString *)path {
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    [self.selectedPaths removeAllObjects];
    
    self.currentPath = path;
    self.pathTextField.text = path;
    
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:&error];
    
    if (error) {
        NSLog(@"Error reading directory: %@", error);
        contents = @[];
    }
    
    contents = [contents sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    [self.currentContents removeAllObjects];
    if (![path isEqualToString:@"/"]) {
        [self.currentContents addObject:@".."];
    }
    [self.currentContents addObjectsFromArray:contents];
    
    [self.selectButton setTitle:@"" forState:UIControlStateNormal];
    self.selectButton.backgroundColor = [UIColor systemBlueColor];
    [self.fileTableView reloadData];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self navigateToPath:textField.text];
    return YES;
}

- (void)setupUI {
    // Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 40, 100, 40)];
    titleLabel.text = @"HMFT";
    titleLabel.font = [UIFont boldSystemFontOfSize:32];
    [self.view addSubview:titleLabel];
    
    // Access level label
    UILabel *accessLabel = [[UILabel alloc] initWithFrame:CGRectMake(120, 42, 200, 20)];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/usr/sbin/mediaserverd"])
        accessLabel.text = @"Filesystem Access: Full ✅";
    else
        accessLabel.text = @"Filesystem Access: Limited ⚠️";
    accessLabel.font = [UIFont systemFontOfSize:14];
    accessLabel.textAlignment = NSTextAlignmentLeft;
    [self.view addSubview:accessLabel];
    
    // Version subtitle
    UILabel *versionLabel = [[UILabel alloc] initWithFrame:CGRectMake(120, 62, 200, 20)];
    versionLabel.text = @"Version: 1.0 - iOS 14";
    versionLabel.font = [UIFont systemFontOfSize:14];
    versionLabel.textAlignment = NSTextAlignmentLeft;
    [self.view addSubview:versionLabel];
    
    // Help button
    UIButton *helpButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    helpButton.frame = CGRectMake(322, 47, 30, 30);
    helpButton.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.3, 1.3);
    [helpButton addTarget:self action:@selector(showHelp) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:helpButton];
    
    
    // Select/Deselect button
    UIButton *selectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    selectButton.frame = CGRectMake(20, 90, 40, 40);
    UIImage *folderImage = [UIImage systemImageNamed:@"folder.fill"];
    [selectButton setImage:folderImage forState:UIControlStateNormal];
    selectButton.backgroundColor = [UIColor systemBlueColor];
    selectButton.tintColor = [UIColor whiteColor];
    selectButton.layer.cornerRadius = 8;
    [selectButton addTarget:self action:@selector(toggleSelection) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:selectButton];
    self.selectButton = selectButton;
    
    // Current path textfield
    self.pathTextField = [[UITextField alloc] initWithFrame:CGRectMake(70, 90, self.view.bounds.size.width - 90, 40)];
    self.pathTextField.font = [UIFont systemFontOfSize:16];
    self.pathTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.pathTextField.delegate = self;
    self.pathTextField.returnKeyType = UIReturnKeyGo;
    [self.view addSubview:self.pathTextField];
    
    // File browser table
    self.fileTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 140, self.view.bounds.size.width, self.view.bounds.size.height - 260) style:UITableViewStylePlain];
    self.fileTableView.delegate = self;
    self.fileTableView.dataSource = self;
    self.fileTableView.allowsMultipleSelection = YES;
    [self.fileTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"FileCell"];
    [self.view addSubview:self.fileTableView];
    
    // Action buttons
    UIButton *checkButton = [UIButton buttonWithType:UIButtonTypeSystem];
    checkButton.frame = CGRectMake(20, self.view.bounds.size.height - 120, self.view.bounds.size.width - 40, 40);
    [checkButton setTitle:@"Check Integrity" forState:UIControlStateNormal];
    checkButton.backgroundColor = [UIColor systemBlueColor];
    [checkButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    checkButton.layer.cornerRadius = 8;
    [checkButton addTarget:self action:@selector(checkIntegrity) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:checkButton];
    
    UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
    extractButton.frame = CGRectMake(20, self.view.bounds.size.height - 70, self.view.bounds.size.width - 40, 40);
    [extractButton setTitle:@"Extract" forState:UIControlStateNormal];
    extractButton.backgroundColor = [UIColor systemBlueColor];
    [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    extractButton.layer.cornerRadius = 8;
    [extractButton addTarget:self action:@selector(extractFiles) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:extractButton];
}

- (void)toggleSelection {
    if (self.selectedPaths.count == 0) {
        // Select all
        for (NSString *filename in self.currentContents) {
            if (![filename isEqualToString:@".."]) {
                NSString *fullPath = [self.currentPath stringByAppendingPathComponent:filename];
                [self.selectedPaths addObject:fullPath];
            }
        }
        self.selectButton.backgroundColor = [UIColor systemGrayColor];
    } else {
        // Deselect all
        [self.selectedPaths removeAllObjects];
        self.selectButton.backgroundColor = [UIColor systemBlueColor];
    }
    [self.fileTableView reloadData];
}

- (void)showProgressAlert:(NSString *)title message:(NSString *)message {
    self.progressAlert = [UIAlertController alertControllerWithTitle:title
                                                           message:message
                                                    preferredStyle:UIAlertControllerStyleAlert];
    
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [spinner startAnimating];
    self.progressAlert.view.tintColor = [UIColor blackColor];
    [self.progressAlert.view addSubview:spinner];
    
    // Center spinner vertically and position it to the right of the title
    [NSLayoutConstraint activateConstraints:@[
        [spinner.centerYAnchor constraintEqualToAnchor:self.progressAlert.view.centerYAnchor constant:-20],
        [spinner.trailingAnchor constraintEqualToAnchor:self.progressAlert.view.trailingAnchor constant:-20]
    ]];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction * action) {
        self.isCancelled = YES;
        [self.operationQueue cancelAllOperations];
    }];
    
    [self.progressAlert addAction:cancelAction];
    [self presentViewController:self.progressAlert animated:YES completion:nil];
}

- (void)extractFiles {
    if (self.selectedPaths.count == 0) {
        [self showAlert:@"No Files Selected" message:@"Please select at least one file."];
        return;
    }
    
    // Create timestamp and filename
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    NSString *archiveName = [self getFormattedFilename:@"files" extension:@"tar.gz"];
        NSString *tempArchivePath = [__NSTemporaryDirectory() stringByAppendingPathComponent:archiveName];
    
    [self showProgressAlert:@"Creating Archive" message:@"Please wait..."];
    self.isCancelled = NO;
    
    [self.operationQueue addOperationWithBlock:^{
        struct archive *a = archive_write_new();
        archive_write_add_filter_gzip(a);
        archive_write_set_format_pax_restricted(a);
        
        int o = archive_write_open_filename(a, tempArchivePath.UTF8String);
        
        if (o) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.progressAlert dismissViewControllerAnimated:YES completion:^{
                    [self showAlert:@"Error" message:@"Failed to create archive"];
                }];
            });
            return;
        }
        
        BOOL success = YES;
        for (NSString *path in self.selectedPaths) {
            if (self.isCancelled) {
                success = NO;
                break;
            }
            
            if (strncmp(path.UTF8String, "/dev", 4) == 0)
                continue;
            
            const char overprovisioning_path[] = "/var/.overprovisioning_file";
            if (strncmp(path.UTF8String, "/var/.overprovisioning_file", sizeof(overprovisioning_path)-1 ) == 0)
                continue;
            
            BOOL isDirectory;
            [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
            
            if (isDirectory) {
                success &= [self addDirectoryToArchive:a path:path];
            } else {
                success &= [self addFileToArchive:a path:path];
            }
        }
        
        archive_write_close(a);
        archive_write_free(a);
        
        if (success && !self.isCancelled) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.progressAlert dismissViewControllerAnimated:YES completion:^{
                    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc]
                        initWithURL:[NSURL fileURLWithPath:tempArchivePath]
                        inMode:UIDocumentPickerModeExportToService];
                    documentPicker.delegate = self;
                    [self presentViewController:documentPicker animated:YES completion:nil];
                }];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.progressAlert dismissViewControllerAnimated:YES completion:^{
                    [self showAlert:@"Error" message:@"Failed to create archive"];
                }];
            });
        }
    }];
}

- (BOOL)addFileToArchive:(struct archive *)a path:(NSString *)path {
    struct archive_entry *entry = archive_entry_new();
    struct stat st;
    
    if (stat([path UTF8String], &st) != 0) {
        archive_entry_free(entry);
        return NO;
    }
    
    archive_entry_set_pathname(entry, [path UTF8String]);
    archive_entry_set_size(entry, st.st_size);
    archive_entry_set_filetype(entry, AE_IFREG);
    archive_entry_set_perm(entry, st.st_mode & 0777);
    archive_entry_set_mtime(entry, st.st_mtime, 0);
    
    archive_write_header(a, entry);
    
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
    NSData *buffer;
    
    while ((buffer = [file readDataOfLength:8192]) && buffer.length > 0) {
        if (self.isCancelled) {
            [file closeFile];
            archive_entry_free(entry);
            return NO;
        }
        archive_write_data(a, buffer.bytes, buffer.length);
    }
    
    [file closeFile];
    archive_entry_free(entry);
    return YES;
}

- (BOOL)addDirectoryToArchive:(struct archive *)a path:(NSString *)dirPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:dirPath];
    NSString *path;
    BOOL success = YES;
    
    while ((path = [enumerator nextObject]) && !self.isCancelled) {
        NSString *fullPath = [dirPath stringByAppendingPathComponent:path];
        BOOL isDirectory;
        [fm fileExistsAtPath:fullPath isDirectory:&isDirectory];
        
        if (!isDirectory) {
            success &= [self addFileToArchive:a path:fullPath];
        }
    }
    
    return success;
}


- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
}


- (NSString *)sha256ForPath:(NSString *)path {
    if (strncmp(path.UTF8String, "/dev", 4) == 0)
        return nil;
    
    const char overprovisioning_path[] = "/var/.overprovisioning_file";
    if (strncmp(path.UTF8String, "/var/.overprovisioning_file", sizeof(overprovisioning_path)-1 ) == 0)
        return nil;
    
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return nil;
    
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);
    
    while (true) {
        if (self.isCancelled) return nil;
        
        NSData *data = [handle readDataOfLength:4096];
        if (data.length == 0) break;
        
        CC_SHA256_Update(&ctx, data.bytes, (CC_LONG)data.length);
    }
    
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(hash, &ctx);
    [handle closeFile];
    
    NSMutableString *hashString = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hashString appendFormat:@"%02x", hash[i]];
    }
    
    return hashString;
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                 message:message
                                                          preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)getFormattedFilename:(NSString *)type extension:(NSString *)ext {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    NSString *rawModel = [self deviceModel];
    NSString *model = self.modelNameMap[rawModel] ?: rawModel;
    NSString *version = [[UIDevice currentDevice] systemVersion];
    
    return [NSString stringWithFormat:@"%@_%@_iOS%@_%@.%@",
            timestamp, model, version, type, ext];
}

- (void)checkIntegrity {
    if (self.selectedPaths.count == 0) {
        [self showAlert:@"No Files Selected" message:@"Please select at least one file."];
        return;
    }
    
    NSString *tempPath = [__NSTemporaryDirectory() stringByAppendingPathComponent:[self getFormattedFilename:@"hashes" extension:@"txt"]];
    
    [self showProgressAlert:@"Checking Integrity" message:@"Calculating SHA256 hashes..."];
    self.isCancelled = NO;
    
    [self.operationQueue addOperationWithBlock:^{
        [[NSFileManager defaultManager] createFileAtPath:tempPath contents:nil attributes:nil];
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:tempPath];
        
        for (NSString *path in self.selectedPaths) {
            if (self.isCancelled) break;
            [self hashPath:path toFileHandle:fileHandle];
        }
        
        [fileHandle closeFile];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.progressAlert dismissViewControllerAnimated:YES completion:^{
                if (!self.isCancelled) {
                    chmod(tempPath.UTF8String, S_IRWXG | S_IRWXO | S_IRWXU);
                    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc]
                        initWithURL:[NSURL fileURLWithPath:tempPath]
                        inMode:UIDocumentPickerModeExportToService];
                    documentPicker.delegate = self;
                    [self presentViewController:documentPicker animated:YES completion:nil];
                }
            }];
        });
    }];
}

- (void)hashPath:(NSString *)path toFileHandle:(NSFileHandle *)fileHandle {
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
    
    if (isDirectory) {
        NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];
        NSString *relativePath;
        while ((relativePath = [enumerator nextObject]) && !self.isCancelled) {
            NSString *fullPath = [path stringByAppendingPathComponent:relativePath];
            BOOL isSubDirectory;
            [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isSubDirectory];
            
            if (!isSubDirectory) {
                NSString *hash = [self sha256ForPath:fullPath];
                if (hash) {
                    NSString *output = [NSString stringWithFormat:@"%@:%@\n", fullPath, hash];
                    NSLog(@"%@", output);
                    [fileHandle writeData:[output dataUsingEncoding:NSUTF8StringEncoding]];
                }
            }
        }
    } else {
        NSString *hash = [self sha256ForPath:path];
        if (hash) {
            NSString *output = [NSString stringWithFormat:@"%@:%@\n", path, hash];
            NSLog(@"%@", output);
            [fileHandle writeData:[output dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
}

- (void)showHelp {
    UIAlertController *helpAlert = [UIAlertController alertControllerWithTitle:@"About HMFT"
        message:@"HMFT is a humble mobile forensics tool for browsing, calculating the hash integrity of, and extracting files from iOS devices.\n\nHMFT allows selecting a single or multiple files, producing their SHA256 hashes with the Check Integrity button, and creating an archive of any files selected saved to Files using the Exrtact button.\n\nHMFT also allows using the Share button next to the filename of any file or directory to share it using Airdrop or other installed apps."
        preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"Close"
                                                        style:UIAlertActionStyleDefault
                                                      handler:nil];
    
    [helpAlert addAction:closeAction];
    [self presentViewController:helpAlert animated:YES completion:nil];
}

@end
