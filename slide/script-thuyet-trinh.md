# Script thuyết trình: LCMFreq

Script này đi theo đúng thứ tự slide trong `slides.pdf` (44 trang). Mỗi mục
ứng với một frame; các trang "Mục lục" tự sinh ở đầu mỗi section chỉ cần
nói 1 câu chuyển ý ngắn, không cần đọc lại danh sách. Thời gian gợi ý cho
toàn bài khoảng 20–25 phút.

---

## Trang 1: Trang bìa

"Em xin chào thầy/cô và các bạn. Nhóm em là nhóm 01, môn CSC14004, Khai
thác dữ liệu và ứng dụng. Đề tài của nhóm là LCMFreq, một thuật toán khai
thác tập phổ biến dựa trên Backtracking kết hợp hai kỹ thuật tăng tốc là
OccurrenceDeliver và HypercubeDecomposition, dựa trên bài báo gốc của
Uno, Kiyomi và Arimura năm 2004."

(Giới thiệu nhanh tên các thành viên nếu giảng viên yêu cầu, không cần đọc
hết bảng trên slide.)

## Trang 2: Nội dung trình bày

"Bài trình bày của nhóm gồm 10 phần: từ đặt vấn đề, khung Backtracking, hai
kỹ thuật cốt lõi của LCMFreq, cách cài đặt bằng Julia, kết quả thực nghiệm,
một ứng dụng thực tế, và kết luận. Mình sẽ đi từng phần."

---

## SECTION 1: Đặt vấn đề

**Trang 3 (mini mục lục):** "Trước tiên là phần đặt vấn đề, để thống nhất
ký hiệu trước khi vào thuật toán."

### Trang 4: Định nghĩa hình thức

"Theo đúng ký hiệu của bài báo gốc: ta có tập item $\mathcal I$, database
là tập các giao dịch, mỗi giao dịch là một tập con của $\mathcal I$. Một
itemset $P$ là một tập con bất kỳ.

Khái niệm quan trọng nhất là **denotation** $\mathcal T(P)$: tập tất cả
giao dịch chứa $P$. Số lượng giao dịch đó gọi là frequency, hay quen gọi
là support. $P$ là frequent nếu support của nó không nhỏ hơn ngưỡng
$\sigma$.

Có hai tính chất nền tảng: denotation của hợp hai itemset bằng giao hai
denotation riêng; và nếu $P$ là tập con của $Q$ thì denotation của $Q$
nằm trong denotation của $P$, nên support của $Q$ không vượt support của
$P$. Bài toán Frequent Itemset Mining là tìm toàn bộ itemset frequent."

### Trang 5: Tính đơn điệu và thứ tự sinh itemset

"Từ tính chất thứ hai, ta suy ra tính đơn điệu: nếu $P$ đã không frequent
thì mọi tập cha của $P$ cũng không frequent. Nhờ vậy, mọi itemset frequent
đều sinh được từ tập rỗng bằng cách thêm item lần lượt, không cần đi qua
itemset không frequent nào.

Nhưng nếu cứ thêm item tự do, một itemset như $\{A,C,D\}$ có thể sinh ra
từ nhiều thứ tự khác nhau, bị tính trùng. Để tránh điều này, ta định nghĩa
$\mathrm{tail}(P)$ là item có chỉ số lớn nhất trong $P$, và chỉ cho phép
thêm item lớn hơn $\mathrm{tail}(P)$. Nhìn vào cây bên dưới: $\{A,C,D\}$
chỉ có đúng một đường sinh duy nhất, đi từ $A$ sang $A,C$ rồi $A,C,D$, các
thứ tự khác như $C,A,D$ không bao giờ được tạo ra."

---

## SECTION 2: Khung Backtracking

**Trang 6 (mini mục lục):** "Tiếp theo, mình nói về khung thuật toán mà
LCMFreq dùng làm nền, gọi là Backtracking."

### Trang 7: Hai nhóm thuật toán cho Frequent Itemset Mining

"Có hai nhóm thuật toán chính. Nhóm Apriori tính itemset theo từng tầng,
tầng $k$ tính từ tầng $k-1$, nhưng phải lưu toàn bộ tầng $k-1$ trong bộ
nhớ. Nhóm Backtracking thì đệ quy, mỗi lượt gọi chỉ giữ một itemset hiện
tại, không cần lưu lại các itemset trước đó, nên tốn ít bộ nhớ hơn.

Bài báo gốc có một câu rất quan trọng: backtracking tốn ít bộ nhớ hơn,
nhưng lại kém hơn Apriori ở khâu đếm support. Đây chính là động cơ của
LCMFreq: chọn khung backtracking để tiết kiệm bộ nhớ, rồi khắc phục đúng
điểm yếu đó bằng hai kỹ thuật mình sẽ trình bày tiếp."

### Trang 8: Khung thuật toán BackTracking

"Đây là pseudo-code gốc của Backtracking: mỗi lượt gọi xuất ra itemset
hiện tại, rồi thử thêm từng item lớn hơn tail, nếu itemset mới vẫn frequent
thì gọi đệ quy tiếp. Khung này tạo ra một cây tìm kiếm, và LCMFreq giữ
nguyên khung này, chỉ thay đổi cách đếm support và cách xuất kết quả bên
trong mỗi lượt gọi."

### Trang 9: Ba kỹ thuật của LCMFreq trên khung Backtracking

"Đây là bức tranh tổng quan trước khi đi vào chi tiết. Backtracking lo
việc không sinh trùng itemset. OccurrenceDeliver lo việc đếm support nhanh
cho mọi candidate cùng lúc. HypercubeDecomposition lo việc xuất nhiều
itemset cùng support trong một lần, không cần đếm lại. Sơ đồ dưới tóm tắt
luồng xử lý tại một node: deliver để có bucket, từ bucket suy ra các item
miễn phí, rồi xuất theo lô. Hai phần tiếp theo mình sẽ đi sâu vào
OccurrenceDeliver và Hypercube."

---

## SECTION 3: Đếm support hiệu quả

**Trang 10 (mini mục lục):** "Phần này là trọng tâm: tại sao phải đếm
support theo cách của LCMFreq, không đếm theo cách thông thường."

### Trang 11: Down project: cách tổng quát để tính denotation

"Down project là cách tổng quát: nếu tách itemset $P$ thành hai phần
$P_1, P_2$, thì denotation của $P$ bằng giao denotation hai phần đó, tính
được trong thời gian tỉ lệ với tổng độ dài hai danh sách.

Nhưng backtracking luôn thêm đúng một item mỗi lượt, nên cách tách duy
nhất là $P_1=P$ và $P_2=\{e\}$. Với $k$ candidate, chi phí cộng dồn có một
số hạng $|\mathcal T(P)|$ lặp lại $k$ lần, một lần cho mỗi candidate, dù
$\mathcal T(P)$ không hề đổi. Đây chính là phần lãng phí mà OccurrenceDeliver
sẽ giải quyết."

### Trang 12: Vì sao OccurrenceDeliver nhanh hơn: ví dụ đếm bước

"Mình minh họa bằng số liệu cụ thể. Tại node $P=\{A\}$, có 3 giao dịch
chứa $A$. Theo cách trực tiếp, ta giao riêng với từng candidate $B$, $C$,
$D$, tổng cộng 21 bước, trong đó 3 giao dịch của $\mathcal T(P)$ bị đọc lại
3 lần.

OccurrenceDeliver chỉ đọc 3 giao dịch đó một lần, mỗi giao dịch tốn đúng
bằng số item nó có, tổng chỉ 6 bước, và hoàn toàn không cần đọc denotation
của $B$, $C$, $D$. Hai mươi mốt bước so với sáu bước, cho cùng một node:
đây là con số cụ thể cho thấy vì sao OccurrenceDeliver nhanh hơn."

### Trang 13: Thuật toán OccurrenceDeliver

"Đây là pseudo-code chính thức theo Mục 3.4 của bài báo: khởi tạo bucket
rỗng cho mỗi candidate, rồi với mỗi giao dịch trong $\mathcal T(P)$, với
mỗi item lớn hơn tail trong giao dịch đó, đẩy giao dịch vào bucket tương
ứng. Sau khi xong, bucket của $e$ chính là denotation của $P$ hợp $e$.

Công thức độ phức tạp ở bên phải cho thấy $|\mathcal T(P)|$ chỉ xuất hiện
một lần, không nhân với số candidate như down project. Bài báo gốc khẳng
định thẳng: complexity này nhỏ hơn down project."

### Trang 14: Minh họa phân phối giao dịch vào bucket

"Đây là hình minh họa cho đúng ví dụ vừa nói. $\mathcal T(P)$ có 3 giao
dịch, OccurrenceDeliver duyệt một lần, mỗi giao dịch được rải vào bucket
của các item nó chứa. Sau một lượt, ta có ngay bucket cho cả ba candidate
cùng lúc."

### Trang 15: Bất biến sau khi deliver

"Đây là điều quan trọng nhất cần nhớ: bucket của $e$ sau khi deliver xong
chính là denotation thật của $P$ hợp $e$, không phải cấu trúc tạm. Vì vậy
support tính được ngay bằng độ dài bucket, và bucket dùng được luôn cho
bước tiếp theo, không cần tính lại gì cả."

### Trang 16: Vì sao không dùng bitmap, theo bài báo gốc

"Một cách khác để tăng tốc down project là dùng bitmap, biểu diễn
denotation bằng dãy bit và giao bằng AND. Nhưng bài báo gốc nói rõ: bitmap
có lợi cho CPU 32 bit, giảm thời gian xuống còn một phần ba mươi hai,
nhưng lại có bất lợi với dataset thưa.

Vì vậy bản gốc của LCMFreq không dùng bitmap, mà dùng OccurrenceDeliver
với mảng số nguyên. Bản tối ưu của nhóm thì lại chọn dùng BitArray, và
đúng như nhận định trên, kết quả thực nghiệm của nhóm cho thấy mức tăng
tốc lớn nhất rơi vào dataset dày đặc như Chess và Pumsb, còn dataset thưa
như Retail tăng tốc khiêm tốn hơn nhiều. Phần thực nghiệm phía sau sẽ cho
thấy rõ điều này."

---

## SECTION 4: HypercubeDecomposition

**Trang 17 (mini mục lục):** "Tiếp theo là kỹ thuật thứ hai: xuất kết quả
theo lô."

### Trang 18: Định nghĩa H(P) và xuất theo lô

"$H(P)$ là tập các item mà khi thêm vào $P$ không làm giảm denotation,
nghĩa là mọi giao dịch chứa $P$ đều chứa luôn item đó. Vì bucket đã có sẵn
từ OccurrenceDeliver, kiểm tra một item có thuộc $H(P)$ hay không chỉ cần
so độ dài bucket với độ dài denotation của $P$, rất rẻ.

Gộp $H(P)$ với tập $S$ tích lũy từ node cha thành $S'$, thuật toán xuất
toàn bộ itemset nằm giữa $P$ và $P$ hợp $S'$ trong một lượt. Bài báo gốc
nói con số cụ thể: tiết kiệm khoảng $2$ lũy $|H(P)|$ lần đếm support."

### Trang 19: Vì sao xuất theo lô vẫn đúng và đủ

"Mình chứng minh ngắn vì sao cách làm này không sai và không thiếu. Nếu
$e$ thuộc $H(P)$ thì denotation không đổi khi thêm $e$. Áp dụng liên tiếp
cho mọi item trong $S'$, denotation vẫn không đổi, nên mọi tổ hợp con của
$S'$ thêm vào $P$ đều có cùng support với $P$.

Hệ quả là: không cần đếm support riêng cho từng tổ hợp, không cần đệ quy
riêng vào các item đã thuộc $S'$, và khi tạo nhánh con thì loại các item
đó ra khỏi danh sách candidate để tránh sinh lại. Hypercube không bỏ sót,
không thêm sai, chỉ gom các node có cùng denotation lại để xuất một lần."

---

## SECTION 5: Pseudo-code và ví dụ chạy tay

**Trang 20 (mini mục lục):** "Để thấy rõ cả ba kỹ thuật phối hợp với nhau
như thế nào, mình đi qua pseudo-code đầy đủ và một ví dụ chạy tay."

### Trang 21: Pseudo-code LCMFreq đầy đủ

"Đây là toàn bộ thuật toán trong một hàm. Tại một node: dòng 4 đến 6 là
OccurrenceDeliver, dựng bucket bằng một lượt duyệt. Dòng 8, 9 suy ra $H(P)$
và gộp vào $S'$. Dòng 11, 12 là Hypercube, xuất hàng loạt $P$ hợp $Q$ với
$Q$ là tập con của $S'$. Dòng 14 đến 17 là đệ quy: chỉ đi tiếp với item
ngoài $S'$ và còn đủ minsup."

### Trang 22: Ví dụ chạy tay: database và bước gốc

"Mình minh họa trên database 5 giao dịch, ngưỡng $\sigma=2$. Tại root,
OccurrenceDeliver cho ra bucket của $A,B,C,D$ với support 4, 5, 4, 3.

Vì bucket của $B$ dài đúng 5, bằng denotation của root, $B$ là item miễn
phí. Ta xuất ngay $\{B\}$ với support 5, không cần đệ quy. Sau đó chỉ đệ
quy tiếp với $A, C, D$; mọi itemset chứa $B$ sẽ tự động được ghép kèm ở
các node con phía sau, không cần một nhánh riêng cho $B$."

### Trang 23: Cây đệ quy trên ví dụ

"Đây là toàn cảnh cây đệ quy. Cây thật chỉ có 7 node, ứng với rỗng, $A$,
$C$, $D$, $AC$, $AD$, $CD$, $ACD$. Tổng cộng có 15 itemset frequent, nhưng
8 trong số đó chứa $B$ và được xuất kèm theo bằng hypercube ngay tại từng
node, không tạo thêm nhánh riêng nào cho $B$. Đây là minh chứng trực quan
cho việc Hypercube giúp giảm số nhánh DFS."

---

## SECTION 6: Cài đặt Julia

**Trang 24 (mini mục lục):** "Bây giờ mình chuyển sang phần cài đặt thực
tế bằng Julia."

### Trang 25: Code Julia baseline: ánh xạ từng khối

"Bên trái là OccurrenceDeliver thật trong code: với mỗi giao dịch trong
denotation của $P$, duyệt từng item, nếu item đó còn là candidate thì đẩy
TID vào bucket. Bên phải là Hypercube: filter giữ lại các item có bucket
dài bằng support hiện tại, rồi gộp với $S$ từ node cha thành $S'$."

### Trang 26: Code Julia baseline: xuất kết quả và đệ quy

"Bên trái sinh mọi tập con của $S'$ và xuất itemset tương ứng, đó là bước
xuất theo lô. Bên phải là vòng lặp quyết định đệ quy: bỏ qua item nhỏ hơn
hoặc bằng tail, bỏ qua item đã thuộc $S'$, bỏ qua item không đủ minsup,
rồi gọi đệ quy với bucket của item còn lại làm denotation mới."

### Trang 27: Tối ưu hóa bằng BitArray

"Khung thuật toán giữ nguyên ở cả hai bản. Baseline lưu denotation bằng
vector số nguyên, bám sát bài báo. Bản tối ưu đổi sang BitArray: mỗi bit
ứng với một giao dịch, giao hai denotation chỉ còn là phép AND bit, đếm
support là đếm số bit 1, tận dụng lệnh phần cứng POPCNT.

Ý tưởng Hypercube không đổi: vẫn kiểm tra denotation có giữ nguyên hay
không, chỉ là phép kiểm tra giờ nhanh hơn nhiều nhờ AND bit."

---

## SECTION 7: Đánh giá thực nghiệm

**Trang 28 (mini mục lục):** "Phần tiếp theo là thực nghiệm, để kiểm
chứng những gì vừa trình bày về lý thuyết."

### Trang 29: Thiết lập thực nghiệm

"Nhóm dùng 9 dataset chuẩn từ kho FIMI, đối chiếu với SPMF viết bằng Java
trên cùng một máy. Các dataset chia làm hai nhóm rõ rệt: nhóm dày đặc như
Chess, Connect, Mushroom, Pumsb, và nhóm thưa như Retail, T10I4D100K,
T40I10D100K, Kosarak. Sự phân chia này sẽ giải thích nhiều khác biệt trong
kết quả tiếp theo."

### Trang 30: Độ phức tạp và yếu tố ảnh hưởng

"Về lý thuyết, chi phí một node tỉ lệ với tổng kích thước giao dịch trong
denotation của $P$, nhờ OccurrenceDeliver. Nhưng tổng thời gian toàn thuật
toán vẫn có thể tăng theo hàm mũ, vì LCMFreq là thuật toán output sensitive:
thời gian chạy gắn với số lượng kết quả phải xuất ra. Bảng dưới tóm tắt
các yếu tố ảnh hưởng: số giao dịch, số item, minsup, độ dài giao dịch, và
việc dataset dày đặc hay thưa."

### Trang 31: Kiểm chứng tính đúng đắn

"Trước khi nói tốc độ, phải chắc kết quả đúng. Trên toàn bộ 9 dataset, số
lượng frequent itemset của bản Julia khớp tuyệt đối 100% với SPMF, không
thiếu, không thừa. Ngoài ra, bộ unit test còn so sánh từng giá trị support
của từng itemset trên các toy dataset nhỏ, đảm bảo đúng cả về nội dung,
không chỉ đúng số lượng."

### Trang 32: Thời gian chạy theo ngưỡng minsup

"Đây là hai ví dụ tiêu biểu. Trên Chess, dataset dày đặc, bản tối ưu nhanh
hơn SPMF từ 76 đến 141 lần. Trên Retail, dataset thưa, mức tăng tốc khiêm
tốn hơn, chỉ khoảng 2 đến 6 lần, vì denotation vốn đã nhỏ nên down project
không tốn nhiều như trên dataset dày đặc. Đáng chú ý, baseline hết bộ nhớ
trên Retail vì Retail có tới 16 nghìn 470 item, còn bản tối ưu vẫn chạy
bình thường."

### Trang 33: Tăng tốc so với SPMF: tổng quan

"Nhìn tổng quan trên cả 8 dataset có so sánh được, mức tăng tốc dao động
từ khoảng 2 lần trên Retail đến 343 lần trên Pumsb. Pumsb đạt cao nhất vì
độ dài giao dịch trung bình tới 74 item, làm khuếch đại lợi thế của phép
AND bit. Riêng Kosarak, SPMF không chạy được trên máy thực nghiệm nên
không có số liệu so sánh trực tiếp."

### Trang 34: Số lượng frequent itemset theo minsup

"Khi giảm minsup, số frequent itemset trên dataset dày đặc tăng theo dạng
hàm mũ, đúng như tính chất đơn điệu đã nói ở phần đầu. Trên dataset thưa,
số lượng tăng chậm hơn nhiều vì ít item đồng xuất hiện đủ thường xuyên.
Đây là minh chứng thực nghiệm cho lý thuyết đã trình bày."

### Trang 35: Sử dụng bộ nhớ

"Về bộ nhớ, BitArray tiết kiệm khoảng 64 lần so với vector số nguyên trên
mỗi denotation, vì mỗi giao dịch chỉ chiếm 1 bit thay vì 8 byte. Quan
trọng hơn, baseline cấp phát mảng theo chỉ số item lớn nhất, nên hết bộ
nhớ trên 7 trong 9 dataset khi item ID thưa. Bản tối ưu dùng cấu trúc kiểu
từ điển, chỉ cấp phát cho item thực sự frequent, nên chạy được trên toàn
bộ 9 dataset."

### Trang 36: Khả năng mở rộng theo kích thước dữ liệu

"Thử nghiệm trên các tập con 10% đến 100% của Retail, giữ nguyên độ khó
bài toán bằng cách tăng minsup tuyệt đối theo tỉ lệ. Thời gian chạy tăng
gần tuyến tính theo số transaction, đúng như lý thuyết, vì số lượng
itemset phổ biến giữ ổn định còn chi phí mỗi phép AND chỉ tăng tuyến tính
theo $n$."

### Trang 37: Ảnh hưởng của độ dài giao dịch

"Thí nghiệm cuối cùng dùng dataset tổng hợp để xem ảnh hưởng riêng của độ
dài giao dịch. Khi độ dài trung bình dưới 25, support kỳ vọng của mọi item
chưa đủ ngưỡng nên kết quả rỗng. Khi độ dài đạt khoảng 30, các itemset
phổ biến xuất hiện đột ngột. Đây gọi là ngưỡng pha chuyển của bài toán
Frequent Itemset Mining."

---

## SECTION 8: Ứng dụng phân tích giỏ hàng

**Trang 38 (mini mục lục):** "Cuối cùng, để cho thấy LCMFreq có ứng dụng
thực tế, nhóm làm thêm một bài toán phân tích giỏ hàng."

### Trang 39: Sinh luật kết hợp từ kết quả LCMFreq

"Từ mỗi itemset frequent, ta sinh các luật kết hợp dạng $Y$ suy ra phần
còn lại, giữ lại luật có độ tin cậy đạt ngưỡng. Chỉ số lift cho biết mức
tương quan thật so với việc hai vế độc lập với nhau.

Trên Retail, với minsup 0.5%, nhóm thu được 580 frequent itemset; với
minconf 60%, sinh được 312 luật kết hợp."

### Trang 40: Top luật kết hợp theo lift trên Retail

"Đây là một số luật có lift cao nhất. Nhóm sản phẩm 38, 39, 41 có lift
trên 7, nghĩa là xác suất đồng xuất hiện cao gấp khoảng 7 lần so với ngẫu
nhiên, là gợi ý tốt cho việc bán theo gói hoặc bố trí gần nhau trên kệ.
Dataset Retail chỉ có mã số sản phẩm, không có tên thật, nên phân tích chỉ
dừng ở mức item ID."

---

## SECTION 9: Kết luận

**Trang 41 (mini mục lục):** "Mình tổng kết lại toàn bộ bài trình bày."

### Trang 42: Kết luận

"Nhóm đã hoàn thành đầy đủ ba kỹ thuật của LCMFreq theo đúng bài báo gốc,
có bản tối ưu BitArray, kiểm thử tự động, khớp 100% với SPMF trên 9
dataset, và một ứng dụng phân tích giỏ hàng.

Về giới hạn, bộ nhớ vẫn còn cao trên dataset rất thưa như T10I4D100K, vì
denotation vẫn lưu toàn bộ BitArray chứ chưa dùng diffset, và chưa khai
thác đa luồng.

Hướng phát triển tiếp theo là áp dụng diffset để giảm bộ nhớ, song song
hóa các nhánh DFS độc lập, và mở rộng sang khai thác closed, maximal
itemset như LCM gốc.

Tóm lại: LCMFreq chọn khung backtracking để tiết kiệm bộ nhớ, khắc phục
điểm yếu đếm support của backtracking bằng OccurrenceDeliver, và giảm số
lần đếm lặp lại bằng HypercubeDecomposition. Bản tối ưu của nhóm không sao
chép SPMF, SPMF chỉ dùng làm chuẩn đối chiếu."

---

## SECTION 10: Tài liệu tham khảo

**Trang 43 (mini mục lục):** "Cuối cùng là tài liệu tham khảo."

### Trang 44: Tài liệu tham khảo

"Tài liệu chính của nhóm là bài báo LCM ver.2 của Uno, Kiyomi và Arimura,
năm 2004, cùng với các công trình nền tảng khác về Apriori, FP-Growth, và
Eclat. Nhóm em xin hết phần trình bày, rất mong nhận được câu hỏi và góp ý
từ thầy/cô và các bạn."

---

## Câu hỏi dự kiến và cách trả lời ngắn

- **Vì sao không dùng FP-tree?** Theo bài báo gốc, LCM không cần tìm kiếm
  lại trong database, chỉ lần theo denotation của nghiệm hiện tại, nên
  không cần cấu trúc cây phức tạp; mảng đơn giản đủ nhanh và ít chi phí
  khởi tạo hơn.
- **Vì sao bản tối ưu dùng BitArray trong khi bài báo nói bitmap không tốt
  cho dataset thưa?** Đây là tối ưu hóa riêng của nhóm, không phải khung
  của bài báo gốc. Vì vậy nhóm vẫn giữ bản baseline bám sát bài báo để đối
  chiếu, và kết quả thực nghiệm cho thấy đúng dự đoán: BitArray lợi nhiều
  trên dataset dày đặc, lợi ít trên dataset thưa.
- **HypercubeDecomposition có làm thay đổi kết quả không?** Không. Đã
  chứng minh ở slide "Vì sao xuất theo lô vẫn đúng và đủ": nó chỉ gom các
  itemset có cùng denotation để xuất một lần, không bỏ sót, không thêm
  sai.
- **Tại sao Kosarak không có số liệu so sánh với SPMF?** SPMF không chạy
  được trên máy thực nghiệm của nhóm với dataset này do kích thước quá
  lớn (gần 1 triệu giao dịch, hơn 41 nghìn item).
