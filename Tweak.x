// IAPSim - kendi oyunum icin StoreKit 1 IAP simulasyonu
// Sadece IAPSim.plist icindeki bundle ID'ye enjekte olur.
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

static const char kIDsKey;

// ---------- Sahte urun ----------
@interface FakeProduct : SKProduct
@property (nonatomic, copy) NSString *fid;
@end
@implementation FakeProduct
- (NSString *)productIdentifier { return self.fid; }
- (NSString *)localizedTitle { return self.fid; }
- (NSString *)localizedDescription { return @"Simulated product"; }
- (NSDecimalNumber *)price { return [NSDecimalNumber decimalNumberWithString:@"0.99"]; }
- (NSLocale *)priceLocale { return [NSLocale localeWithLocaleIdentifier:@"en_US"]; }
@end

// ---------- Sahte urun cevabi ----------
@interface FakeResponse : SKProductsResponse
@property (nonatomic, copy) NSArray *fproducts;
@end
@implementation FakeResponse
- (NSArray *)products { return self.fproducts; }
- (NSArray *)invalidProductIdentifiers { return @[]; }
@end

// ---------- Sahte islem ----------
@interface FakeTransaction : SKPaymentTransaction
@property (nonatomic, strong) SKPayment *fpayment;
@property (nonatomic, copy) NSString *fid;
@property (nonatomic, strong) NSDate *fdate;
@end
@implementation FakeTransaction
- (SKPaymentTransactionState)transactionState { return SKPaymentTransactionStatePurchased; }
- (SKPayment *)payment { return self.fpayment; }
- (NSString *)transactionIdentifier { return self.fid; }
- (NSDate *)transactionDate { return self.fdate; }
- (NSError *)error { return nil; }
- (SKPaymentTransaction *)originalTransaction { return nil; }
@end

static NSArray *observersOf(SKPaymentQueue *q) {
    SEL s = @selector(transactionObservers);
    if ([q respondsToSelector:s]) {
        return [q performSelector:s];
    }
    return @[];
}

%hook SKPaymentQueue
+ (BOOL)canMakePayments { return YES; }

- (void)addPayment:(SKPayment *)payment {
    FakeTransaction *t = [FakeTransaction new];
    t.fpayment = payment;
    t.fid = [[NSUUID UUID] UUIDString];
    t.fdate = [NSDate date];
    NSArray *txs = @[t];
    dispatch_async(dispatch_get_main_queue(), ^{
        for (id<SKPaymentTransactionObserver> o in observersOf(self)) {
            if ([o respondsToSelector:@selector(paymentQueue:updatedTransactions:)]) {
                [o paymentQueue:self updatedTransactions:txs];
            }
        }
    });
}

- (void)finishTransaction:(SKPaymentTransaction *)transaction {
    if ([transaction isKindOfClass:[FakeTransaction class]]) return;
    %orig;
}

- (void)restoreCompletedTransactions {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (id<SKPaymentTransactionObserver> o in observersOf(self)) {
            if ([o respondsToSelector:@selector(paymentQueueRestoreCompletedTransactionsFinished:)]) {
                [o paymentQueueRestoreCompletedTransactionsFinished:self];
            }
        }
    });
}
%end

%hook SKProductsRequest
- (instancetype)initWithProductIdentifiers:(NSSet<NSString *> *)ids {
    id r = %orig;
    objc_setAssociatedObject(r, &kIDsKey, ids, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return r;
}

- (void)start {
    NSSet *ids = objc_getAssociatedObject(self, &kIDsKey);
    id<SKProductsRequestDelegate> d = self.delegate;
    if (!ids || !d) { %orig; return; }

    NSMutableArray *list = [NSMutableArray array];
    for (NSString *pid in ids) {
        FakeProduct *p = [FakeProduct new];
        p.fid = pid;
        [list addObject:p];
    }
    FakeResponse *resp = [FakeResponse new];
    resp.fproducts = list;

    dispatch_async(dispatch_get_main_queue(), ^{
        [d productsRequest:self didReceiveResponse:resp];
        if ([d respondsToSelector:@selector(requestDidFinish:)]) {
            [d requestDidFinish:self];
        }
    });
}
%end
