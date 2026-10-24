# 오픈소스 고지

## Sub-features

- 설정창에서 고지창을 연다.
- Credits·Origins·Licenses 페이지를 전환한다.
- 번들 라이선스 내용을 읽고 창을 닫는다.

## How to get to it (user POV)

Neat 설정창 하단의 `오픈소스 고지` 링크를 누른다.

## Driving it with CUA

설정창이 기존에 열려 있었는지 기록한다. `neatApp.getAXState()`에서 `오픈소스 고지` 링크의 최신 인덱스를 찾아 `neatApp.click(index)`를 실행한다. 새 AX에서 Credits 페이지의 기여자 감사 문구를 확인한다.

Origins의 실제 라벨을 찾아 클릭한다. Ice·Jordan Baird와 Barometer 관련 본문으로 바뀌었는지 확인한다. Licenses를 클릭하고 번들 라이브러리 라이선스 본문이 표시되는지 확인한다. 로드 실패 문구는 실패다. 한국어 UI에서도 이번 관찰에서는 페이지 버튼이 영어로 표시됐다. 항상 관찰된 라벨을 사용한다.

각 클릭 전후 AX와 스크린샷을 기록한다. 고지창의 닫기 버튼을 누르고 설정창 복귀를 확인한다. 이번 실행에서 연 설정창만 닫는다. 배치·스위치 값이 시작 상태와 같은지 확인한다.

## Gotchas

Contribute·Help translate·기여자 링크는 브라우저를 연다. 페이지 전환 검증에는 필요하지 않다. Credits 화면만 열면 나머지 페이지 검증은 미완료다.

구현 근거는 `Settings/SettingsPanes/AcknowledgementsView.swift`, 라이선스 원본은 `Resources/Acknowledgements.rtf`다.
