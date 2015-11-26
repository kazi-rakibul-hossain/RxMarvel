//
//  HeroAPI.swift
//  FunctionalMarvel
//
//  Created by Segii Shulga on 11/24/15.
//  Copyright © 2015 Sergey Shulga. All rights reserved.
//

import Foundation
import RxSwift
import Argo

struct HeroAPI {
   static var getableApi:JsonGET.Type = Marvel.self
   private static let decodeScheduler = SerialDispatchQueueScheduler(internalSerialQueueName: "com.FunctionalMarvel.HeroAPI.decode_queue")
   typealias HeroListResult = (heroes:Decoded<[Hero]>, batch:Decoded<Batch>)
   
   private static func recursiveHeroList(offset:Int = 0,
      limit:Int,
      search:String?,
      loadNextBatch:Observable<Void>) -> Observable<[Hero]>  {
         
         let params:[String : AnyObject] = [ ParamKeys.limit : limit, ParamKeys.offset : String(offset)] + (search != nil ? [ParamKeys.searchName : search!] : [:])
         
      return heroListSignal(params)
         .flatMap { (tuple) -> Observable<[Hero]>  in
            
            guard let heroes = tuple.heroes.value,
               let batch = tuple.batch.value  else {
                  return empty()
            }
            
            if batch.offset == batch.total
               || batch.offset + batch.count == batch.total {
                  //                     Here we've downloaded all data
                  return empty()
            }
            
            return [
               just(heroes),
               never().takeUntil(loadNextBatch),
               recursiveHeroList(batch.count + batch.offset,
                  limit: batch.limit,
                  search: search,
                  loadNextBatch: loadNextBatch)
               ].concat()
      }
   }
   
   static func heroListSignal(params:[String:AnyObject]? = nil) -> Observable<HeroListResult> {
      
      return getableApi
         .getData(.Characters)(parameters: params)
         .observeOn(decodeScheduler)
         .map(HeroDecoder.decode)
   }
   
}

extension HeroAPI {
   struct HeroDecoder {
      static func decode(j:AnyObject) -> HeroListResult {
         if let dict = JSONDict(j)(key: "data"),
            let array = dict["results"] {
               return (Argo.decode(array), Argo.decode(dict))
         }
         return (Decoded.Failure(DecodeError.Custom("Invalid JSON")), Decoded.Failure(DecodeError.Custom("Invalid JSON")))
      }
   }
}

extension HeroAPI:HeroAutoLoad {
   static func getItems(offset: Int = 0,
      limit:Int = 40,
      search:String?,
      loadNextBatch: Observable<Void>) -> Observable<[Hero]> {
      return recursiveHeroList(offset, limit: limit, search:search, loadNextBatch: loadNextBatch)
   }
}

