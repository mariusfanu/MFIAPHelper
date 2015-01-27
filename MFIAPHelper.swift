//
//  MFIAPHelper.swift
//
//
//  Created by Marius Fanu on 27/01/15.
//  Copyright (c) 2015 Marius Fanu. All rights reserved.
//

import UIKit
import StoreKit

let IAPHelperProductPurchaseNotification = "In-App Purchase Product Notification"

typealias RequestProductCompletionHandler =  (success: Bool, products: NSArray) -> ()

class MFIAPHelper: NSObject, SKPaymentTransactionObserver, SKProductsRequestDelegate {
    
    // MARK: - Properties
    var productsRequest: SKProductsRequest!
    var completionHandler: RequestProductCompletionHandler?
    var productIdentifiers: NSSet
    var purchasedProductIdentifiers: NSMutableSet
    
    // MARK: - Life Cycle
    init(productIdentifiers: NSSet) {
        self.productIdentifiers = productIdentifiers
        purchasedProductIdentifiers = NSMutableSet()
        super.init()
        
        for productIdentifier in productIdentifiers {
            var productPurchased = NSUserDefaults.standardUserDefaults().boolForKey(productIdentifier as String)
            
            if productPurchased {
                purchasedProductIdentifiers.addObject(productIdentifier as String)
                println("Previously purchased: \(productIdentifier)")
            }
            else {
                println("Not purchased: \(productIdentifier)")
            }
        }
        
        SKPaymentQueue.defaultQueue().addTransactionObserver(self)
    }
    
    func requestProductsWithCompletionHandler(callback: RequestProductCompletionHandler) {
        self.completionHandler = callback
        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest.delegate = self
        productsRequest.start()
        
    }
    // MARK: - Purchase methods
    func productPurchased(productIdentifier: String) -> Bool {
        if purchasedProductIdentifiers.count == 0 {
            return NSUserDefaults.standardUserDefaults().boolForKey(productIdentifier)
        }
        else {
            return purchasedProductIdentifiers.containsObject(productIdentifier)
        }
    }
    
    func buyProduct(product: SKProduct) {
        println("Buying \(product.productIdentifier)")
        
        if !SKPaymentQueue.canMakePayments() {
            println("Can't make payments")
            return
        }
        var payment = SKPayment(product: product)
        SKPaymentQueue.defaultQueue().addPayment(payment)
    }
    
    // MARK: - SKPaymentTransactionObserver
    
    func paymentQueue(queue: SKPaymentQueue!, updatedTransactions transactions: [AnyObject]!) {
        for transaction in transactions as Array<SKPaymentTransaction> {
            switch transaction.transactionState {
            case .Purchased:
                completeTransaction(transaction)
            case .Failed:
                faliedTransaction(transaction)
            case .Restored:
                restoreTransaction(transaction)
            default:
                break;
            }
        }
    }
    
    func completeTransaction(transaction: SKPaymentTransaction) {
        println("Complete transaction...")
        provideContentForProductIdentifier(transaction.payment.productIdentifier)
        SKPaymentQueue.defaultQueue().finishTransaction(transaction)
    }
    func faliedTransaction(transaction: SKPaymentTransaction) {
        println("Falied transaction...")
        if transaction.error.code != SKErrorPaymentCancelled {
            println("Transaction error = \(transaction.error.localizedDescription)")
        }
        SKPaymentQueue.defaultQueue().finishTransaction(transaction)
    }
    func restoreTransaction(transaction: SKPaymentTransaction) {
        println("Restore transaction...")
        provideContentForProductIdentifier(transaction.payment.productIdentifier)
        SKPaymentQueue.defaultQueue().finishTransaction(transaction)
    }
    
    func provideContentForProductIdentifier(productIdentifier: String) {
        purchasedProductIdentifiers.addObject(productIdentifier)
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: productIdentifier)
        NSUserDefaults.standardUserDefaults().synchronize()
        NSNotificationCenter.defaultCenter().postNotificationName(IAPHelperProductPurchaseNotification, object: productIdentifier)
    }
    
    func restoreCompletedTransactions() {
        SKPaymentQueue.defaultQueue().restoreCompletedTransactions()
    }
    
    func paymentQueue(queue: SKPaymentQueue!, restoreCompletedTransactionsFailedWithError error: NSError!) {
        println("\(error.localizedDescription)")
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(queue: SKPaymentQueue!) {
        println("Received restored transactions: \(queue.transactions)")
        
        for transaction in queue.transactions as [SKPaymentTransaction] {
            var productIdentifier = transaction.payment.productIdentifier
            println("Restored: \(productIdentifier)")
            
            // Check to see if product identifier is already restored
            if !productIdentifiers.containsObject(productIdentifier) {
                purchasedProductIdentifiers .addObject(productIdentifiers)
                NSUserDefaults.standardUserDefaults().setBool(true, forKey: productIdentifier)
                NSUserDefaults.standardUserDefaults().synchronize()
                NSNotificationCenter.defaultCenter().postNotificationName(IAPHelperProductPurchaseNotification, object: productIdentifier)
            }
        }
        
        if queue.transactions.count == 0 {
            println("No purchases to restore")
        }
        else {
            println("Your purchases have been successfully restored")
        }
    }
   
    // MARK: SKProductsRequestDelegate
    
    func productsRequest(request: SKProductsRequest!, didReceiveResponse response: SKProductsResponse!) {
        println("Loaded list of products...")
        
        for product in response.products as [SKProduct] {
            println("Found product \(product.productIdentifier) \(product.localizedTitle) \(product.priceLocale)")
        }
        
        if let callback = completionHandler {
            callback(success: true, products: response.products as NSArray)
            completionHandler = nil
        }
        
    }
    func request(request: SKRequest!, didFailWithError error: NSError!) {
        println("Falied to load list of products")
        println("Error: \(error.localizedDescription)")
        
    }
}
