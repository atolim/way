# [SwiftUI] NSKeyValueObservation와 TCA Store 간의 순환 참조 문제 분석 및 해결

## 1. SwiftUI View(Struct)와 클로저의 관계
SwiftUI의 View는 구조체입니다. 구조체는 값 타입이므로 그 자체로 순환 참조를 만들지는 않습니다. 하지만 @State로 선언된 프로퍼티는 힙(Heap) 메모리 영역에 별도의 저장 공간을 가집니다.

`offsetObserver`는 @State로 관리되므로, `RecordPostFeedView` 인스턴스가 사라져도 이 옵저버 객체는 시스템에 의해 유지될 수 있습니다.

`collectionView.observe`가 반환하는 `NSKeyValueObservation` 객체는 내부 클로저(핸들러)를 강하게 참조합니다.

## 2. 순환 참조의 연결 고리 분석
작성하신 코드에서의 참조 흐름은 다음과 같습니다:

1. **View(State)**가 `offsetObserver` 객체를 소유함.
2. `offsetObserver` 객체가 내부 **클로저(핸들러)**를 소유함.
3. 클로저가 `store`를 참조함.
   - 여기서 `store`는 `StoreOf<RecordPostFeedCore>`라는 클래스 인스턴스입니다 (TCA의 Store는 클래스입니다).

만약 클로저 내부에서 `[weak store]` 없이 `store.send(...)`를 호출하면 클로저가 store를 강하게 잡습니다.

**[핵심 문제점]**
`store`는 보통 해당 화면의 생명주기와 함께해야 하는데, `offsetObserver`가 `store`를 강하게 잡고 있고, 이 옵저버는 다시 View의 `@State`에 의해 유지되므로, 화면이 닫혀도 `store`가 메모리에서 해제되지 않는 상황이 발생할 수 있습니다.

## 3. 주석에 대한 피드백
> "observer에 내부 클로저가 있음, 내부 클로저에서 store을 참조하고 있음(강하게), offsetObserver 여기서 observer을 참조하는데 observer의 내부 클로저를 같이 참조. 순환참조 발생"

이 분석은 매우 정확합니다. 특히 `NSKeyValueObservation`은 수동으로 `invalidate()`를 하거나 객체가 할당 해제되어야 감시를 멈추는데, 클로저가 `store`를 강하게 잡으면 `store -> view -> observer -> store` 형태의 논리적 고리가 생겨 메모리가 해제되지 않습니다.

## 4. 해결 방법
이미 코드에 해결책이 반영되어 있습니다:

```swift
let observer = collectionView.observe(\.contentOffset, options: [.new]) { [weak store] scrollView, change in
    // [weak store]를 통해 강한 참조를 끊음
    guard let newOffset = change.newValue?.y else { return }
    DispatchQueue.main.async {
        store?.send(.onScroll(newOffset)) 
    }
}
```

이렇게 **[weak store]**를 사용하면 클로저가 `store`의 레퍼런스 카운트를 올리지 않기 때문에, 화면이 나갈 때 `store`와 `view`가 정상적으로 메모리에서 해제될 수 있습니다.
