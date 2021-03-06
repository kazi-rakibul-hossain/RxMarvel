//
//  HeroAPI.swift
//  FunctionalMarvel
//
//  Created by Segii Shulga on 6/5/16.
//  Copyright © 2016 Sergey Shulga. All rights reserved.
//

import Foundation
import Argo
import RxSwift
import Alamofire

protocol HeroAPI {
    func paginateItems(batch: Batch,
    endPoint: EndPoint,
    nextBatchTrigger: Observable<Void>) -> Observable<[Hero]>
    
    func searchItems(query: String,
    batch: Batch,
    endPoint: EndPoint,
    nextBatchTrigger: Observable<Void>) -> Observable<[Hero]>
}

class DefaultHeroAPI: HeroAPI {
    let httpClient: HttpClient
    let paramsProvider: ParamsProvider.Type
    static let decodeScheduler = SerialDispatchQueueScheduler(internalSerialQueueName: "com.RxMarvel.DefaultHeroAPI.decodeQueue")
    
    init(httpClient: HttpClient = Manager.sharedInstance,
         paramsProvider: ParamsProvider.Type = HeroesParamsProvider.self) {
        self.httpClient = httpClient
        self.paramsProvider = paramsProvider
    }
    
    func paginateItems(batch: Batch = Batch.initial,
                       endPoint: EndPoint,
                       nextBatchTrigger: Observable<Void>) -> Observable<[Hero]> {
        return recursivelyPaginateItems(batch, endPoint: endPoint, nextBatchTrigger: nextBatchTrigger)
            .scan([], accumulator: { (acum, page) in
                return acum + page.item
            })
    }
    
    private func recursivelyPaginateItems(batch: Batch,
                                  endPoint: EndPoint,
                                  nextBatchTrigger: Observable<Void>) -> Observable<Page<[Hero]>> {
        let params = paramsProvider.pagingListParamsForBatch(batch)
        return httpClient
            .request(.GET, endPoint,
                parameters: paramsProvider.defaultParams + params,
                encoding: .URL,
                headers: nil)
            .observeOn(DefaultHeroAPI.decodeScheduler)
            .map(PagingParser<Hero>.parse)
            .paginate(nextBatchTrigger,
                      hasNextPage: { (page) -> Bool in
                        return page.batch.next().hasNextPage
            }) { [weak self] (page) -> Observable<Page<[Hero]>> in
                return self?.recursivelyPaginateItems(page.batch.next(),
                                           endPoint: endPoint,
                                           nextBatchTrigger: nextBatchTrigger) ?? Observable.empty()
            }
    }
    
    func searchItems(query: String,
                     batch: Batch = Batch.initial,
                     endPoint: EndPoint,
                     nextBatchTrigger: Observable<Void>) -> Observable<[Hero]> {
        return recursivelySearch(query,
            endPoint: endPoint,
            nextBatchTrigger: nextBatchTrigger)
            .scan([], accumulator: { (items, page) in
                return items + page.item
            })
    }
    
    private func recursivelySearch(query: String,
                     batch: Batch = Batch.initial,
                     endPoint: EndPoint,
                     nextBatchTrigger: Observable<Void>) -> Observable<Page<[Hero]>> {
      
        let params = paramsProvider.pagingListSearchParamsForQuery(query, batch: batch)
      
        return httpClient
            .request(.GET,
                endPoint,
                parameters: params,
                encoding: .URL,
                headers: nil)
            .observeOn(DefaultHeroAPI.decodeScheduler)
            .map(PagingParser<Hero>.parse)
            .paginate(nextBatchTrigger,
                      hasNextPage: { (page) -> Bool in
                        return page.batch.next().hasNextPage
                },
                      nextPageFactory: { [weak self] (page) -> Observable<Page<[Hero]>> in
                        return self?.recursivelySearch(query,
                            batch: page.batch.next(),
                            endPoint: endPoint,
                            nextBatchTrigger: nextBatchTrigger) ?? Observable.empty()
            })
    }

}
