import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Business Tracker Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFFF07C00),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF07C00)),
      ),
      home: const DashboardScreen(),
    );
  }
}

// ---------------- LOCAL DATABASE ----------------
class DBHelper {
  static Database? _db;

  static Future<Database> getDatabase() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'smart_hisab_v1.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            month_year TEXT,
            product_name TEXT,
            customer_name TEXT,
            customer_phone TEXT,
            buy_price REAL,
            sell_price REAL,
            profit REAL,
            supplier_name TEXT,
            supplier_phone TEXT,
            expiry_date TEXT,
            payment_status TEXT,
            cust_refund REAL,
            supplier_refund REAL
          )
        ''');
      },
    );
    return _db!;
  }

  static Future<int> insert(Map<String, dynamic> data) async {
    final db = await getDatabase();
    return await db.insert('records', data);
  }

  static Future<List<Map<String, dynamic>>> getMonthlyData(String monthYear) async {
    final db = await getDatabase();
    return await db.query('records', where: 'month_year = ?', whereArgs: [monthYear], orderBy: 'id DESC');
  }

  static Future<int> updateStatus(int id, String status) async {
    final db = await getDatabase();
    return await db.update('records', {'payment_status': status}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> delete(int id) async {
    final db = await getDatabase();
    return await db.delete('records', where: 'id = ?', whereArgs: [id]);
  }
}

// ---------------- MARQUEE ANIMATED BANNER ----------------
class RunningTextBanner extends StatefulWidget {
  final String text;
  const RunningTextBanner({super.key, required this.text});

  @override
  State<RunningTextBanner> createState() => _RunningTextBannerState();
}

class _RunningTextBannerState extends State<RunningTextBanner> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    while (_scrollController.hasClients) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        await _scrollController.animateTo(
          maxScroll,
          duration: Duration(seconds: (maxScroll / 25).clamp(8, 50).toInt()),
          curve: Curves.linear,
        );
      }
      await Future.delayed(const Duration(milliseconds: 300));
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        "${widget.text}               ${widget.text}               ",
        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 12),
      ),
    );
  }
}

// ---------------- DASHBOARD SCREEN ----------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _records = [];
  String _searchQuery = '';
  final String myAdminPhone = '+8801782409169';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  String get _currentMonthYear => DateFormat('MMM yyyy').format(_selectedDate);

  void _loadData() async {
    final data = await DBHelper.getMonthlyData(_currentMonthYear);
    setState(() {
      _records = data;
    });
  }

  void _pickMonthYear() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'মাস ও বছর নির্বাচন করুন',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  void _openWhatsApp(String phone, String message) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _exportToExcel() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('এই মাসে কোনো ডাটা নেই!')));
      return;
    }

    StringBuffer csv = StringBuffer();
    csv.writeln("তারিখ,পণ্য,কাস্টমার,মোবাইল,ক্রয় মূল্য,বিক্রয় মূল্য,লাভ,সাপ্লায়ার,সাপ্লায়ার মোবাইল,মেয়াদ,পেমেন্ট স্ট্যাটাস,কাস্টমার রিফান্ড,সাপ্লায়ার রিফান্ড");

    for (var r in _records) {
      csv.writeln(
        '"${r['date']}","${r['product_name']}","${r['customer_name']}","${r['customer_phone']}","${r['buy_price']}","${r['sell_price']}","${r['profit']}","${r['supplier_name']}","${r['supplier_phone']}","${r['expiry_date']}","${r['payment_status']}","${r['cust_refund']}","${r['supplier_refund']}"'
      );
    }

    try {
      final directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final path = "${directory.path}/Report_$_currentMonthYear.csv";
      final file = File(path);
      await file.writeAsString(csv.toString());

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('এক্সেল (CSV) ফাইল সেভ হয়েছে'),
            content: Text('ফাইল লোকেশন:\n$path'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ঠিক আছে'))
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ফাইল তৈরি করতে সমস্যা হয়েছে')));
    }
  }

  Widget _buildAdBanner(String text, String adMessage) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.amber.shade400, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(child: RunningTextBanner(text: text)),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _openWhatsApp(myAdminPhone, adMessage),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shopping_cart, color: Colors.white, size: 12),
                  SizedBox(width: 3),
                  Text('Order Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalSales = 0;
    double grossProfit = 0;
    double totalExpense = 0;

    for (var r in _records) {
      totalSales += (r['sell_price'] as num);
      grossProfit += (r['profit'] as num);
      totalExpense += (r['buy_price'] as num);
    }
    double netIncome = grossProfit;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF07C00),
        title: const Text('Business Tracker Pro', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        actions: [
          TextButton.icon(
            onPressed: _pickMonthYear,
            icon: const Icon(Icons.calendar_month, color: Colors.white, size: 16),
            label: Text(_currentMonthYear, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          IconButton(
            onPressed: _exportToExcel,
            icon: const Icon(Icons.file_download, color: Colors.white),
            tooltip: 'Export Excel',
          )
        ],
      ),
      body: Column(
        children: [
          _buildAdBanner(
            '🔥 প্রিমিয়াম টুলস ও সফটওয়্যার ডিসকাউন্ট মূল্যে কিনুন! যেকোনো প্রয়োজনে যোগাযোগ করুন — ',
            'আসসালামু আলাইকুম, আমি আপনার অ্যাপের ওপরের ব্যানার দেখে অর্ডার করতে নক দিয়েছি।'
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildMetricCard('TOTAL SALES', '৳ ${totalSales.toStringAsFixed(0)}', Colors.blue),
                    _buildMetricCard('GROSS PROFIT', '৳ ${grossProfit.toStringAsFixed(0)}', Colors.teal),
                  ],
                ),
                Row(
                  children: [
                    _buildMetricCard('TOTAL EXPENSE', '৳ ${totalExpense.toStringAsFixed(0)}', Colors.red),
                    _buildMetricCard('NET INCOME', '৳ ${netIncome.toStringAsFixed(0)}', Colors.orange.shade800),
                  ],
                ),
              ],
            ),
          ),

          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFFF07C00),
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: const Color(0xFFF07C00),
              tabs: const [
                Tab(text: 'Transactions'),
                Tab(text: 'Due List'),
                Tab(text: 'Product Report'),
                Tab(text: 'Daily Report'),
                Tab(text: 'Expiry Reminder'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionsTab(),
                _buildDueListTab(),
                _buildProductReportTab(),
                _buildDailyReportTab(),
                _buildExpiryReminderTab(),
              ],
            ),
          ),

          _buildAdBanner(
            '🚀 ব্যবসার জন্য ওয়েবসাইট, অ্যাপ এবং ডিজিটাল মার্কেটিং সেবা নিতে এখনই অর্ডার করুন — ',
            'আসসালামু আলাইকুম, আমি সার্ভিস বুকিংয়ের জন্য আপনার সাথে যোগাযোগ করতে চাই।'
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 40.0),
        child: FloatingActionButton.extended(
          backgroundColor: const Color(0xFFF07C00),
          onPressed: () => _showAddEntryDialog(),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('New Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsTab() {
    final filtered = _records.where((r) =>
      r['customer_name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
      r['product_name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
      r['customer_phone'].toString().contains(_searchQuery)
    ).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'কাস্টমার, পণ্য বা মোবাইল দিয়ে সার্চ করুন...',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('কোনো এন্ট্রি পাওয়া যায়নি'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(item['product_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('কাস্টমার: ${item['customer_name']} | ${item['date']}', style: const TextStyle(fontSize: 12)),
                            Text('সাপ্লায়ার: ${item['supplier_name'] ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('৳ ${item['sell_price']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('লাভ: ৳${item['profit']}', style: const TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.bold)),
                            Text(item['payment_status'], style: TextStyle(
                              color: item['payment_status'] == 'Paid' ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 11
                            )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDueListTab() {
    final dueRecords = _records.where((r) => r['payment_status'] == 'Due' || r['payment_status'] == 'Partial').toList();
    if (dueRecords.isEmpty) {
      return const Center(child: Text('এই মাসে কোনো বকেয়া নেই! 🎉', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)));
    }

    return ListView.builder(
      itemCount: dueRecords.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final row = dueRecords[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(row['customer_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('৳ ${row['sell_price']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                Text('পণ্য: ${row['product_name']} | মোবাইল: ${row['customer_phone']}', style: const TextStyle(fontSize: 12)),
                Text('স্ট্যাটাস: ${row['payment_status']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () {
                        final msg = "আসসালামু আলাইকুম ${row['customer_name']}, আপনার '${row['product_name']}' বাবদ ৳${row['sell_price']} টাকা বকেয়া রয়েছে। পরিশোধের বিনীত অনুরোধ রইল।";
                        _openWhatsApp(row['customer_phone'], msg);
                      },
                      icon: const Icon(Icons.send, size: 14, color: Colors.white),
                      label: const Text('WhatsApp তাগিদ', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      onPressed: () async {
                        await DBHelper.updateStatus(row['id'], 'Paid');
                        _loadData();
                      },
                      child: const Text('Mark Paid', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductReportTab() {
    Map<String, Map<String, dynamic>> productStats = {};
    for (var r in _records) {
      String p = r['product_name'];
      if (!productStats.containsKey(p)) {
        productStats[p] = {'count': 0, 'total_sell': 0.0, 'total_profit': 0.0};
      }
      productStats[p]!['count'] += 1;
      productStats[p]!['total_sell'] += (r['sell_price'] as num);
      productStats[p]!['total_profit'] += (r['profit'] as num);
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: productStats.entries.map((e) {
        return Card(
          child: ListTile(
            title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('মোট বিক্রি: ${e.value['count']} টি', style: const TextStyle(fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('বিক্রি: ৳${e.value['total_sell'].toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('মোট লাভ: ৳${e.value['total_profit'].toStringAsFixed(0)}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDailyReportTab() {
    Map<String, Map<String, dynamic>> dailyStats = {};
    for (var r in _records) {
      String date = r['date'];
      if (!dailyStats.containsKey(date)) {
        dailyStats[date] = {'sales': 0.0, 'profit': 0.0, 'count': 0};
      }
      dailyStats[date]!['sales'] += (r['sell_price'] as num);
      dailyStats[date]!['profit'] += (r['profit'] as num);
      dailyStats[date]!['count'] += 1;
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: dailyStats.entries.map((e) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_today, color: Color(0xFFF07C00), size: 20),
            title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('মোট লেনদেন: ${e.value['count']} টি', style: const TextStyle(fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('সেল: ৳${e.value['sales'].toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('লাভ: ৳${e.value['profit'].toStringAsFixed(0)}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpiryReminderTab() {
    final withExpiry = _records.where((r) => r['expiry_date'] != null && r['expiry_date'].toString().isNotEmpty).toList();

    if (withExpiry.isEmpty) {
      return const Center(child: Text('কোনো এক্সপায়ারি ডেট যুক্ত রেকর্ড নেই'));
    }

    return ListView.builder(
      itemCount: withExpiry.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final row = withExpiry[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(row['product_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('মেয়াদ: ${row['expiry_date']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                Text('গ্রাহক: ${row['customer_name']} | মোবাইল: ${row['customer_phone']}', style: const TextStyle(fontSize: 12)),
                const Divider(),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                    onPressed: () {
                      final msg = "আসসালামু আলাইকুম ${row['customer_name']}, আপনার ক্রয়কৃত '${row['product_name']}'-এর মেয়াদ ${row['expiry_date']} তারিখে শেষ হতে চলেছে। রিনিউ করতে আমাদের সাথে যোগাযোগ করুন।";
                      _openWhatsApp(row['customer_phone'], msg);
                    },
                    icon: const Icon(Icons.notifications_active, color: Colors.white, size: 15),
                    label: const Text('রিনিউ সতর্কবার্তা (WhatsApp)', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddEntryDialog() {
    final prodCtrl = TextEditingController();
    final custCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final buyCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    final supCtrl = TextEditingController();
    final supPhoneCtrl = TextEditingController();
    final custRefCtrl = TextEditingController(text: '0');
    final supRefCtrl = TextEditingController(text: '0');

    String selectedStatus = 'Paid';
    DateTime? selectedExpiry;
    double calculatedProfit = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) {
          void updateProfit() {
            double b = double.tryParse(buyCtrl.text) ?? 0;
            double s = double.tryParse(sellCtrl.text) ?? 0;
            setMState(() {
              calculatedProfit = s - b;
            });
          }

          return Padding(
            padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('নতুন ডাটা এন্ট্রি', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(controller: prodCtrl, decoration: const InputDecoration(labelText: 'পণ্যের নাম *', isDense: true)),
                  TextField(controller: custCtrl, decoration: const InputDecoration(labelText: 'কাস্টমারের নাম *', isDense: true)),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'কাস্টমার মোবাইল *', isDense: true),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (phoneCtrl.text.isNotEmpty) {
                            _openWhatsApp(phoneCtrl.text, 'আসসালামু আলাইকুম');
                          }
                        },
                        icon: const Icon(Icons.whatsapp, color: Colors.green),
                      )
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: buyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'ক্রয় মূল্য (৳)', isDense: true),
                          onChanged: (_) => updateProfit(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: sellCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'বিক্রয় মূল্য (৳) *', isDense: true),
                          onChanged: (_) => updateProfit(),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text('অটো লাভ (Profit): ৳ ${calculatedProfit.toStringAsFixed(0)}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: supCtrl, decoration: const InputDecoration(labelText: 'Supplier / Company', isDense: true))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: supPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Supplier Mobile', isDense: true))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(selectedExpiry == null ? 'মেয়াদ সিলেক্ট করুন' : 'মেয়াদ: ${DateFormat('dd MMM yyyy').format(selectedExpiry!)}', style: const TextStyle(fontSize: 13)),
                      TextButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: const Text('তারিখ বাছুন', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2040),
                          );
                          if (p != null) setMState(() => selectedExpiry = p);
                        },
                      )
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Payment Status: ', style: TextStyle(fontSize: 13)),
                      DropdownButton<String>(
                        value: selectedStatus,
                        items: ['Paid', 'Due', 'Partial'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) => setMState(() => selectedStatus = val!),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: custRefCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cust. Refunded (৳)', isDense: true))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: supRefCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Supplier Refunded (৳)', isDense: true))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF07C00), minimumSize: const Size.fromHeight(40)),
                    onPressed: () async {
                      if (prodCtrl.text.isEmpty || sellCtrl.text.isEmpty) return;

                      await DBHelper.insert({
                        'date': DateFormat('dd MMM yyyy').format(DateTime.now()),
                        'month_year': _currentMonthYear,
                        'product_name': prodCtrl.text,
                        'customer_name': custCtrl.text,
                        'customer_phone': phoneCtrl.text,
                        'buy_price': double.tryParse(buyCtrl.text) ?? 0.0,
                        'sell_price': double.tryParse(sellCtrl.text) ?? 0.0,
                        'profit': calculatedProfit,
                        'supplier_name': supCtrl.text,
                        'supplier_phone': supPhoneCtrl.text,
                        'expiry_date': selectedExpiry != null ? DateFormat('dd MMM yyyy').format(selectedExpiry!) : '',
                        'payment_status': selectedStatus,
                        'cust_refund': double.tryParse(custRefCtrl.text) ?? 0.0,
                        'supplier_refund': double.tryParse(supRefCtrl.text) ?? 0.0,
                      });

                      Navigator.pop(ctx);
                      _loadData();
                    },
                    child: const Text('সংরক্ষণ করুন', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
