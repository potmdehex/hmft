#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIDocumentPickerDelegate, UIActivityItemSource>
@property (nonatomic, strong) NSDictionary *modelNameMap;
@property (nonatomic, strong) NSMutableSet *selectedForSharing;
@property (nonatomic, strong) UIButton *selectButton;
@property (nonatomic, strong) UITableView *fileTableView;
@property (nonatomic, strong) UITextField *pathTextField;
@property (nonatomic, strong) NSString *currentPath;
@property (nonatomic, strong) NSMutableArray *currentContents;
@property (nonatomic, strong) NSMutableSet *selectedPaths;
@property (nonatomic, strong) UIAlertController *progressAlert;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, assign) BOOL isCancelled;

@end
