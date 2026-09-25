# MenuBarSwitcher

macOS のメニューバーに「⋯」を表示し、アクセシビリティ API が公開する他アプリのメニューバー項目を一覧から選択する試作です。状態と操作は The Composable Architecture (TCA) で管理します。

## 現在できること

- 「⋯」を開くと、検出した項目を横並びで表示します。
- 項目を選ぶと、その項目自身にアクセシビリティの `AXPress` を送ります。対応する場合、元の位置でアプリのメニューが開きます。
- アクセシビリティ権限がない場合は理由と設定手順を表示します。許可後に「更新」を押すと再検出します。権限ダイアログが表示されない場合は「システム設定を開く」から直接設定を開けます。
- キーボードの Tab と Space / Return でボタンを操作でき、VoiceOver にはアプリ名と項目名を読み上げるラベルを付けています。

## 制約

公開 API では、他アプリのステータス項目をこのアプリの「⋯」の中へ物理的に移動したり、元のメニューバーから隠したりできません。そのため、この版ではメニューバーの占有幅を減らせません。項目の複製メニューも作らず、元の項目へ操作を渡します。

項目がアクセシビリティ階層にない、`AXPress` を公開しない、アプリが応答しないなどの場合は一覧に出ないか、押下に失敗します。元の項目を直接操作してください。ノッチで隠れた項目がアクセシビリティ階層に残るかは、対象アプリと macOS の状態に依存します。メニューバーの自動非表示、外部ディスプレイ、複数ディスプレイでも公開 API が返す項目のみを表示します。

実機での項目検出・押下、VoiceOver、権限拒否後の案内、画面構成ごとの操作は未検証です。

## 実行

Xcode で `MenuBarSwitcher/MenuBarSwitcher.xcodeproj` を開き、macOS ターゲットを実行します。「⋯」からアクセスを要求し、システム設定 → プライバシーとセキュリティ → アクセシビリティで許可します。ダイアログが表示されない場合は「システム設定を開く」を使ってください。許可後は「更新」を押します。以前のビルドを実行中なら終了し、変更後のアプリを再ビルドして起動してください。

他アプリのアクセシビリティ要素を扱うため、App Sandbox を無効にしています。この構成は Mac App Store への配布には適しません。

公開 API の根拠: [NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem)、[AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement_h)、[AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)。
