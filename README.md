
以下 Scratch2Romo の説明です。

ご不明な点がございましたら遠慮なくご連絡ください。

よろしくお願いいたします。


==

scratch2romo で Romo を動かすには iPad であればピョンキー

https://itunes.apple.com/jp/app/pyonki/id905012686?mt=8

Windows または Mac であれば Scratch 1.4 が必要です。

http://scratch.mit.edu/scratch_1.4/


以後の説明で Scratch と言った場合、ピョンキーまたは Scratch 1.4 を
指します。

Scratch をインストールした端末と Romo に接続する
iPhone とは、同じネットワークに接続している必要があります。
Scratch をインストールした端末のIPアドレスをひかえておきます。
(iPad の IP アドレスを知るにはたとえば fing
https://itunes.apple.com/jp/app/fing-network-scanner/id430921107?mt=8
のようツールが必要です)

Scratch を起動して、左上、青の「調べる」を選び「スライダーセンサーの値」
ブロックの上で右クリックして、「遠隔センサー接続を有効にする」を
選んでください。


romo2scratch をインストールした iPhone を Romo に差します。
このとき、Romo 公式アプリが起動してしまいますが、こちらは閉じて、
Romo2Scratch を起動します。

scratch host address に Scratch が起動している端末の IP アドレスを入力し、
Connect をタップします。Connected と表示されたら接続 OK です。

Scratch から Romo に送れる命令は、

forward - 前進
backward - 後退
right - 右に曲がる
left - 左に曲がる
up - 上を向く
down - 下を向く

photo - 写真を撮る
light on - ライト点灯
light off - ライトを消す

です。

また以下の変数をスクラッチからセットすることができます。

speed (0 - 100) Romo のスピード
degrees (0 - 360) 曲がるときの角度
steps (-100 - 100) forward または backward を命令したときの進む距離

さらに以下の値をセンサーの値として取得できます。

heading (0 - 360) Romo の向いている方向、北が 0
audio (-30 - 0) iPhone のマイクが取る音量レベル

PC/Mac にインストールした Scratch であれば添付したサンプルプログラム
scratch2romo_test.sb を開いてお使いいただくのが良いかと思います。