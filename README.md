# MenuBarSwitcher

macOS のメニューバーに「⋯」を表示し、アクセシビリティ API が公開する他アプリのメニューバー項目を一覧から選択する試作です。状態と操作は The Composable Architecture (TCA) で管理します。

## 現在できること

- 「⋯」を開くと、コントロールセンターを除く検出済みの項目を横並びに表示します。アクセシビリティで項目の位置を取得し、対応するステータス項目のウィンドウから元のアイコン画像を個別に取得します。画面に表示されていない項目も取得対象です。ウィンドウは項目が全て並ぶ幅まで広がり、操作中の画面の幅を上限にします。画面の右端に合わせて表示し、項目が収まりきらない場合は横スクロールできます。項目名とアプリ名はホバー時と VoiceOver で確認できます。
- 項目を選ぶと、その項目自身にアクセシビリティの `AXPress` を送ります。対応する場合、元の位置でアプリのメニューが開きます。
- アクセシビリティまたは画面収録の権限がない場合は理由と設定手順を表示します。許可後に「⋯」を開き直すと再検出します。権限ダイアログが表示されない場合は「システム設定を開く」から直接設定を開けます。
- キーボードの Tab と Space / Return でボタンを操作でき、VoiceOver にはアプリ名と項目名を読み上げるラベルを付けています。
- Option キーを押しながら「⋯」をクリックすると、macOS 標準のメニューに「Open at Login」と「Quit MenuBarSwitcher」が表示されます。通常の項目一覧は表示されません。
- 「Open at Login」で、ログイン時の自動起動を切り替えられます。macOS 側の許可待ちになった場合は、システム設定の「ログイン項目と機能拡張」で許可してください。

## 制約

公開 API では、他アプリのステータス項目をこのアプリの「⋯」の中へ物理的に移動したり、元のメニューバーから隠したりできません。そのため、この版ではメニューバーの占有幅を減らせません。項目の複製メニューも作らず、元の項目へ操作を渡します。

項目がアクセシビリティ階層にない、`AXPress` を公開しない、アプリが応答しないなどの場合は一覧に出ないか、押下に失敗します。元の項目を直接操作してください。ノッチで隠れた項目がアクセシビリティ階層に残るかは、対象アプリと macOS の状態に依存します。メニューバーの自動非表示、外部ディスプレイ、複数ディスプレイでも公開 API が返す項目のみを表示します。

公開 API は他アプリがステータス項目に設定した `NSImage` 自体を取り出せません。非表示のウィンドウ画像を得るため、macOS 15 で廃止扱いとなった `CGWindowListCreateImageFromArray` を実行時に探して使用します。macOS 26.6.2 の実機では、表示中15件と非表示14件の項目すべてから画像を取得できました。将来の macOS でこの関数が削除された場合や個別の取得に失敗した場合は ScreenCaptureKit を試し、それでも撮影できなければアクセシビリティ上の項目名を表示します。アプリアイコンには置き換えません。項目名も公開されない場合は同じアプリ内での番号を表示します。

アプリからの項目押下、VoiceOver、権限拒否後の案内、画面構成ごとの操作は未検証です。

## 実行

Xcode で `MenuBarSwitcher/MenuBarSwitcher.xcodeproj` を開き、macOS ターゲットを実行します。「⋯」からアクセスを要求し、システム設定 → プライバシーとセキュリティ → アクセシビリティと画面収録とシステムオーディオ録音で許可します。ダイアログが表示されない場合は「システム設定を開く」を使ってください。許可後はアプリを再起動して「⋯」を開き直します。以前のビルドを実行中なら終了し、変更後のアプリを再ビルドして起動してください。

他アプリのアクセシビリティ要素を扱うため、App Sandbox を無効にしています。この構成は Mac App Store への配布には適しません。

API の根拠: [NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem)、[AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement_h)、[AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)、[CGWindowListCreateImageFromArray](https://developer.apple.com/documentation/coregraphics/1454852-cgwindowlistcreateimagefromarray)、[SCShareableContent](https://developer.apple.com/documentation/screencapturekit/scshareablecontent)、[SCScreenshotManager](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager)。

非表示項目の画像取得方式は [Lloyd](https://github.com/benwbooth/lloyd) の公開実装を参考にしました（MIT License）。
