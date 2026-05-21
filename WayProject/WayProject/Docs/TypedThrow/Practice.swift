//
//  Practice.swift
//  WayProject
//
//  Created by 임주영 on 5/21/26.
//

import Foundation

// 1. 구체적인 에러 타입 정의
enum OrderError: Error {
  case outOfStock(item: String)
  case invalidPaymentMethod
  case minimumAmountNotMet(required: Int)
}

// 2. Typed Throws를 사용하는 함수 정의 (OrderError 타입만 던질 수 있음)
func placeOrder(item: String, price: Int, isCardValid: Bool) throws(OrderError) {
  // 결제 수단 확인
  guard isCardValid else {
    throw .invalidPaymentMethod
  }
  
  // 최소 금액 확인
  if price < 1000 {
    throw .minimumAmountNotMet(required: 1000)
  }
  
  // 재고 확인 시뮬레이션
  if item == "품절상품" {
    throw .outOfStock(item: item)
  }
  
  print("✅ \(item) 주문이 완료되었습니다.")
}

// 3. 에러 처리 실습
func runPractice() {
  print("--- 1. 정상 주문 케이스 ---")
  do {
    try placeOrder(item: "아메리카노", price: 3500, isCardValid: true)
  } catch {
    // 컴파일러가 `error`를 자동으로 `OrderError` 타입으로 추론합니다.
    switch error {
    case .outOfStock(let item):
      print("❌ 품절 에러: \(item)")
    case .invalidPaymentMethod:
      print("❌ 결제 실패 에러")
    case .minimumAmountNotMet(let required):
      print("❌ 최소 주문 금액 미달: \(required)원 이상 주문해야 합니다.")
    }
  }
  
  print("\n--- 2. 결제 실패 케이스 ---")
  do {
    try placeOrder(item: "라떼", price: 4000, isCardValid: false)
  } catch {
    // catch 블록에서 별도의 타입 캐스팅(as? OrderError)이 필요하지 않습니다.
    switch error {
    case .outOfStock(let item):
      print("❌ 품절 에러: \(item)")
    case .invalidPaymentMethod:
      print("❌ 결제 실패 에러")
    case .minimumAmountNotMet(let required):
      print("❌ 최소 주문 금액 미달: \(required)원 이상 주문해야 합니다.")
    }
  }
}
