# 타입드 스로우 (Typed Throws)

Swift 6.0(SE-0413)에서 새롭게 도입된 **Typed Throws**는 함수나 메서드가 던질 수 있는 에러의 타입을 구체적으로 지정할 수 있게 해주는 기능입니다.

---

## 1. 등장 배경 및 개요

기존 Swift의 에러 처리 구조에서는 `throws` 키워드만 사용 가능했으며, 이 경우 함수는 임의의 에러(`any Error` 프로토콜을 준수하는 모든 타입)를 던질 수 있었습니다.

* **기존 방식의 단점:**
  * 함수가 어떤 구체적인 에러를 던지는지 코드 시그니처만 보고 명확히 알 수 없습니다.
  * 에러를 받는 쪽(`catch` 블록)에서 구체적인 타입으로 처리하려면 항상 다운캐스팅(`as? MyError`)을 해야 했습니다.
  * 메모리 할당이 불가능하거나 제한적인 환경(예: Embedded Swift) 또는 성능 최적화가 극도로 필요한 상황에서 `any Error`가 가지는 오버헤드가 걸림돌이 되었습니다.

**타입드 스로우**는 이러한 한계를 극복하기 위해 `throws(ErrorType)` 형태로 구체적인 에러 타입을 시그니처에 명시할 수 있도록 합니다.

---

## 2. 기본 문법 및 비교

### 기존 던지기 (Untyped Throws)
```swift
enum ValidationError: Error {
  case emptyName
  case invalidAge
}

// 명시하지 않으면 암시적으로 `any Error`를 던집니다.
func validateUser(name: String) throws {
    if name.isEmpty {
      throw ValidationError.emptyName
  }
}

do {
  try validateUser(name: "")
} catch {
  // 여기서 error 변수는 `any Error` 타입이므로 캐스팅이 필요합니다.
  if let validationError = error as? ValidationError {
      print("에러 발생: \(validationError)")
  }
}
```

### 타입드 던지기 (Typed Throws)
```swift
// 에러 타입을 `ValidationError`로 명시합니다.
func validateUserTyped(name: String) throws(ValidationError) {
  if name.isEmpty {
      throw ValidationError.emptyName
  }
}

do {
  try validateUserTyped(name: "")
} catch {
  // 캐스팅 없이 `error` 변수가 자동으로 `ValidationError` 타입으로 타입 추론됩니다!
  switch error {
  case .emptyName:
      print("이름이 비어 있습니다.")
  case .invalidAge:
      print("나이가 올바르지 않습니다.")
  }
}
```

---

## 3. 특수 케이스 표현

타입드 스로우는 기존의 스로우 구문 및 비동기 처리와 완벽하게 호환되며, 컴파일러 관점에서 다음과 같이 매핑됩니다.

1. **`throws` == `throws(any Error)`**
   * 기존처럼 에러 타입을 생략하고 `throws`만 적으면 자동으로 `any Error`를 던지는 것으로 해석됩니다.
2. **`throws(Never)`**
   * 에러를 절대 던지지 않는 함수를 의미합니다. 즉, 일반적인 던지지 않는 함수(Non-throwing function)와 컴파일러 수준에서 동일하게 취급됩니다.

---

## 4. 타입드 스로우의 장점

1. **타입 안전성 (Type Safety):** 
   * 컴파일러가 함수 내부에서 지정한 에러 타입 외의 다른 에러를 던지려고 하면 컴파일 에러를 발생시켜 실수를 방지합니다.
2. **가독성 및 사용 편의성:**
   * `catch` 블록 내부에서 번거로운 다운캐스팅 코드가 사라져 코드가 간결해집니다.
3. **제네릭(Generics)과의 연계:**
   * 다른 함수를 매개변수로 받아 실행하고 에러를 그대로 전파(Rethrow)하는 제네릭 함수를 설계할 때 매우 유용합니다.
   ```swift
   func callAndPropagate<E: Error>(_ action: () throws(E) -> Void) throws(E) {
       try action()
   }
   ```
4. **성능 최적화 및 제한된 환경 지원:**
   * 런타임에 에러 객체를 박싱/언박싱하는 비용이 줄어들며, 가비지 컬렉션이나 복잡한 런타임 프레임워크가 없는 Embedded Swift 환경에서도 에러 처리를 완전하게 지원합니다.

---

## 5. 실무 적용 시 고려해야 할 점 (Best Practices)

> [!WARNING]
> 모든 곳에 타입드 스로우를 사용하는 것이 무조건 모범 사례는 아닙니다.

* **API 진화와 유연성:**
  * 만약 함수가 던지는 에러 타입(`ValidationError`)을 미래에 다른 타입(`SystemError` 등)으로 변경하거나 추가해야 한다면, 함수를 호출하는 모든 클라이언트 코드의 `catch` 문이 깨지게 됩니다.
  * 반면 `any Error`를 사용하면 에러 타입이 추가되거나 변경되어도 클라이언트 소스 코드의 호환성을 비교적 쉽게 유지할 수 있습니다.
* **추천 사용 대상 및 예시:**

  1. **모듈 내부의 `private` 헬퍼 함수**
     * 외부로 노출되지 않고 내부에서만 소모되는 에러는 외부 스펙 아웃(Breaking Change) 걱정이 없으므로, 컴파일러가 강력하게 에러 타입을 추론하도록 하여 내부 구현 코드의 가독성을 대폭 높일 수 있습니다.
     * **예시:**
       ```swift
       class UserProfileManager {
           // 클래스 내부에서만 사용하는 에러
           private enum ImageUploadError: Error {
               case invalidFormat
               case sizeLimitExceeded
           }
           
           // 내부 헬퍼 함수에 적용해 명확한 에러 추론과 안전성 획득
           private func uploadAvatar(_ data: Data) throws(ImageUploadError) {
               guard data.count < 5_000_000 else { throw .sizeLimitExceeded }
               // ...
           }
       }
       ```

  2. **에러의 종류가 명확하게 고정되어 있고 바뀔 가능성이 거의 없는 도메인 로직**
     * 신용카드 결제 유효성 검사, 비밀번호 복잡도 규칙 등 도메인 규칙이 명확히 한정되어 있어 미래에도 에러 타입이 수정될 일이 거의 없는 곳에 최적입니다.
     * **예시:**
       ```swift
       enum PasswordStrengthError: Error {
           case tooShort           // 8자 미만
           case missingSpecialChar // 특수문자 누락
       }

       func checkPasswordStrength(_ input: String) throws(PasswordStrengthError) {
           if input.count < 8 { throw .tooShort }
           // ...
       }
       ```

  3. **Embedded Swift 등 특수 환경 타겟을 개발할 때**
     * 임베디드 장비(MCU 등)나 dynamic allocation(메모리 동적 할당)이 불가능하거나 런타임 메타데이터가 극도로 제한되는 **Embedded Swift** 환경에서는 `any Error`가 가리키는 실체(Existential)를 표현할 수 없습니다. 따라서 이 경우 반드시 타입드 스로우를 사용해 에러를 전달해야 합니다.
     * **예시:**
       ```swift
       // Embedded Swift 환경 (heap 할당이 불가한 베어메탈 등)
       enum HardwareSensorError: Error {
           case connectionLost
           case dataCorrupted
       }

       // 에러 처리를 런타임 오버헤드 없이 컴파일 타임에 완벽히 추론
       func readTemperature() throws(HardwareSensorError) -> Double {
           // ...
       }
       ```

  4. **고성능 라이브러리나 프레임워크 설계 시 에러 전달 오버헤드를 최소화해야 할 때**
     * 일반 `throws`(`any Error`)는 런타임에 에러 인스턴스를 dynamic memory 영역에 래핑(Boxing)하여 에러를 던지기 때문에 힙 할당 오버헤드가 동반됩니다. 반면 `throws(ErrorType)`은 구체적인 타입을 알기 때문에 힙 할당 없이 레지스터나 스택 영역을 통해 직접 에러를 즉시 전달하므로 에러 발생 시 성능 저하가 없습니다.
     * **예시:**
       ```swift
       // 핫 루프(Hot loop)나 프레임 버퍼 파싱 등 고속 처리가 요구되는 상황
       enum ByteParserError: Error {
           case unexpectedEOF
           case checksumMismatch
       }

       // 힙 할당이 전혀 발생하지 않아 에러 처리 속도가 일반 Return만큼 빠르게 최적화됨
       func parseNextChunk(from buffer: UnsafeRawPointer) throws(ByteParserError) -> Chunk {
           // ...
       }
       ```
