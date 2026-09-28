import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MilkBillingApp());
}

class Product {
  final String id;
  final String name;
  final String gujarati;
  final int price;

  const Product({
    required this.id,
    required this.name,
    required this.gujarati,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gujarati': gujarati,
        'price': price,
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        gujarati: json['gujarati'] as String,
        price: (json['price'] as num).toInt(),
      );
}

class Customer {
  final String id;
  final String name;
  final String address;
  final String mobile;

  const Customer({
    required this.id,
    required this.name,
    required this.address,
    required this.mobile,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? address,
    String? mobile,
  }) =>
      Customer(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        mobile: mobile ?? this.mobile,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'mobile': mobile,
      };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        mobile: json['mobile'] as String,
      );
}

class Distribution {
  final String date;
  final String customerId;
  final Map<String, int> quantities;

  const Distribution({
    required this.date,
    required this.customerId,
    required this.quantities,
  });

  int totalPouches() => quantities.values.fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
        'date': date,
        'customerId': customerId,
        'quantities': quantities,
      };

  factory Distribution.fromJson(Map<String, dynamic> json) => Distribution(
        date: json['date'] as String,
        customerId: json['customerId'] as String,
        quantities: Map<String, int>.from(
          (json['quantities'] as Map).map(
            (key, value) => MapEntry(key.toString(), (value as num).toInt()),
          ),
        ),
      );
}

const defaultProducts = <Product>[
  Product(id: 'P001', name: 'Sampoorna Milk', gujarati: 'સંપૂર્ણા દૂધ', price: 37),
  Product(id: 'P002', name: 'Cow Milk', gujarati: 'ગાયનું દૂધ', price: 30),
  Product(id: 'P003', name: 'A2 Milk', gujarati: 'A2 દૂધ', price: 40),
  Product(id: 'P004', name: 'Super Gold 500ML', gujarati: 'સુપર ગોલ્ડ 500ML', price: 29),
  Product(id: 'P005', name: 'Tak Chhas', gujarati: 'તાક છાશ', price: 17),
];

class AppStore extends ChangeNotifier {
  static const _customersKey = 'customers';
  static const _distributionsKey = 'distributions';

  List<Customer> customers = const [];
  List<Distribution> distributions = const [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final customerRaw = prefs.getString(_customersKey);
    if (customerRaw == null) {
      customers = const [
        Customer(
          id: 'C001',
          name: 'Kirti Khanana',
          address: 'A-802, Banavari Residency, Vesu',
          mobile: '9824751517',
        ),
      ];
    } else {
      final list = jsonDecode(customerRaw) as List;
      customers = list
          .map((e) => Customer.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final distributionRaw = prefs.getString(_distributionsKey);
    if (distributionRaw != null) {
      final list = jsonDecode(distributionRaw) as List;
      distributions = list
          .map((e) => Distribution.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customersKey,
      jsonEncode(customers.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _distributionsKey,
      jsonEncode(distributions.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addCustomer({
    required String name,
    required String address,
    required String mobile,
  }) async {
    final number = customers.length + 1;
    final customer = Customer(
      id: 'C${number.toString().padLeft(3, '0')}',
      name: name.trim(),
      address: address.trim(),
      mobile: mobile.trim(),
    );
    customers = [...customers, customer];
    await _save();
    notifyListeners();
  }

  Future<void> updateCustomer(Customer customer) async {
    customers = customers
        .map((c) => c.id == customer.id ? customer : c)
        .toList();
    await _save();
    notifyListeners();
  }

  Future<void> deleteCustomer(String id) async {
    customers = customers.where((c) => c.id != id).toList();
    distributions = distributions.where((d) => d.customerId != id).toList();
    await _save();
    notifyListeners();
  }

  Future<void> saveDistribution({
    required String customerId,
    required DateTime date,
    required Map<String, int> quantities,
  }) async {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final remaining = distributions.where(
      (d) => !(d.customerId == customerId && d.date == dateKey),
    );

    distributions = [
      ...remaining,
      Distribution(
        date: dateKey,
        customerId: customerId,
        quantities: Map<String, int>.from(quantities),
      ),
    ];

    await _save();
    notifyListeners();
  }

  int monthTotal(String customerId, DateTime month) {
    var total = 0;
    for (final d in distributions) {
      if (d.customerId != customerId) continue;
      final parts = d.date.split('-');
      if (parts.length != 3) continue;
      final year = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (year != month.year || m != month.month) continue;

      for (final entry in d.quantities.entries) {
        final product = productById(entry.key);
        if (product != null) total += entry.value * product.price;
      }
    }
    return total;
  }

  int monthPouches(String customerId, DateTime month) {
    var total = 0;
    for (final d in distributions) {
      if (d.customerId != customerId) continue;
      final parts = d.date.split('-');
      if (parts.length != 3) continue;
      if (int.tryParse(parts[0]) == month.year &&
          int.tryParse(parts[1]) == month.month) {
        total += d.totalPouches();
      }
    }
    return total;
  }
}

Product? productById(String id) {
  for (final p in defaultProducts) {
    if (p.id == id) return p;
  }
  return null;
}

class MilkBillingApp extends StatefulWidget {
  const MilkBillingApp({super.key});

  @override
  State<MilkBillingApp> createState() => _MilkBillingAppState();
}

class _MilkBillingAppState extends State<MilkBillingApp> {
  final store = AppStore();

  @override
  void initState() {
    super.initState();
    store.load();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Milk Billing App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F5663)),
          scaffoldBackgroundColor: const Color(0xFFF7FAFC),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: HomeScreen(store: store),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final AppStore store;
  const HomeScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    var todayPouches = 0;
    var todayAmount = 0;
    for (final d in store.distributions) {
      if (d.date != todayKey) continue;
      todayPouches += d.totalPouches();
      for (final e in d.quantities.entries) {
        final p = productById(e.key);
        if (p != null) todayAmount += e.value * p.price;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Milk Billing'),
        centerTitle: false,
        backgroundColor: const Color(0xFF0F5663),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: store.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _welcomeCard(context),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    icon: Icons.people,
                    label: 'Customers',
                    value: '${store.customers.length}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    icon: Icons.local_drink,
                    label: 'Today Pouches',
                    value: '$todayPouches',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _statCard(
              icon: Icons.currency_rupee,
              label: 'Today Sales',
              value: '₹$todayAmount',
              wide: true,
            ),
            const SizedBox(height: 18),
            _menuCard(
              context,
              Icons.people_alt,
              'Customers',
              'Add, edit and manage customers',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerScreen(store: store),
                ),
              ),
            ),
            _menuCard(
              context,
              Icons.local_drink,
              'Product List',
              'Milk and chhas rates',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProductListScreen(),
                ),
              ),
            ),
            _menuCard(
              context,
              Icons.calendar_today,
              'Daily Distribution',
              'Customer-wise pouch entry',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DistributionSelectScreen(store: store),
                ),
              ),
            ),
            _menuCard(
              context,
              Icons.receipt_long,
              'Monthly Billing',
              'Automatic monthly total',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MonthlySelectScreen(store: store),
                ),
              ),
            ),
            _menuCard(
              context,
              Icons.payments,
              'Payment',
              'Cash, QR, Wallet and NFC',
              () => _showPaymentDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeCard(BuildContext context) {
    return Card(
      color: const Color(0xFFE7F3F5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFF0F5663),
              child: Icon(Icons.local_drink, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Welcome to Milk Billing\nદૂધ બિલિંગ સરળ બનાવો',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    bool wide = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0F5663), size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (wide) const Icon(Icons.trending_up),
          ],
        ),
      ),
    );
  }

  Widget _menuCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE7F3F5),
          child: Icon(icon, color: const Color(0xFF0F5663)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _showPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Payment Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final method in ['Cash', 'QR', 'Wallet', 'NFC'])
              ListTile(
                leading: Icon(_paymentIcon(method)),
                title: Text(method),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$method payment selected')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _paymentIcon(String method) {
    switch (method) {
      case 'QR':
        return Icons.qr_code;
      case 'Wallet':
        return Icons.account_balance_wallet;
      case 'NFC':
        return Icons.contactless;
      default:
        return Icons.money;
    }
  }
}

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product List')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: defaultProducts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final p = defaultProducts[index];
          return Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              leading: CircleAvatar(
                child: Text(p.name.substring(0, 1).toUpperCase()),
              ),
              title: Text(
                p.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(p.gujarati),
              trailing: Text(
                '₹${p.price}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CustomerScreen extends StatelessWidget {
  final AppStore store;
  const CustomerScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _customerDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Customer'),
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (_, __) {
          if (store.customers.isEmpty) {
            return const Center(child: Text('No customers found'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: store.customers.length,
            itemBuilder: (_, index) {
              final c = store.customers[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(c.id.substring(1))),
                  title: Text(
                    '${c.id} • ${c.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${c.address}\n${c.mobile}'),
                  isThreeLine: true,
                  onTap: () => _customerDialog(context, existing: c),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _customerDialog(context, existing: c);
                      } else if (value == 'delete') {
                        await store.deleteCustomer(c.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _customerDialog(
    BuildContext context, {
    Customer? existing,
  }) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final address = TextEditingController(text: existing?.address ?? '');
    final mobile = TextEditingController(text: existing?.mobile ?? '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add Customer' : 'Edit Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Customer Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: address,
                decoration:
                    const InputDecoration(labelText: 'Customer Address'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mobile,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile Number'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              if (existing == null) {
                await store.addCustomer(
                  name: name.text,
                  address: address.text,
                  mobile: mobile.text,
                );
              } else {
                await store.updateCustomer(
                  existing.copyWith(
                    name: name.text,
                    address: address.text,
                    mobile: mobile.text,
                  ),
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );

    name.dispose();
    address.dispose();
    mobile.dispose();
  }
}

class DistributionSelectScreen extends StatelessWidget {
  final AppStore store;
  const DistributionSelectScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Customer')),
      body: AnimatedBuilder(
        animation: store,
        builder: (_, __) => ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: store.customers.length,
          itemBuilder: (_, index) {
            final c = store.customers[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text('${c.id} • ${c.name}'),
                subtitle: Text(c.mobile),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DistributionScreen(store: store, customer: c),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class DistributionScreen extends StatefulWidget {
  final AppStore store;
  final Customer customer;

  const DistributionScreen({
    super.key,
    required this.store,
    required this.customer,
  });

  @override
  State<DistributionScreen> createState() => _DistributionScreenState();
}

class _DistributionScreenState extends State<DistributionScreen> {
  late Map<String, int> quantities;

  @override
  void initState() {
    super.initState();
    quantities = {for (final p in defaultProducts) p.id: 0};
  }

  int get totalPouches =>
      quantities.values.fold(0, (sum, value) => sum + value);

  int get totalAmount {
    var total = 0;
    for (final e in quantities.entries) {
      final p = productById(e.key);
      if (p != null) total += e.value * p.price;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Distribution')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: totalPouches == 0 ? null : _save,
            icon: const Icon(Icons.save),
            label: Text('SAVE • ₹$totalAmount'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                widget.customer.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle:
                  Text('${widget.customer.id} • ${widget.customer.mobile}'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Date: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          for (final p in defaultProducts) _productCard(p),
          Card(
            child: ListTile(
              title: const Text('Total Pouches'),
              trailing: Text(
                '$totalPouches',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(Product p) {
    final q = quantities[p.id] ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('${p.gujarati} • ₹${p.price}/pouch'),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  onPressed: q == 0
                      ? null
                      : () => setState(() => quantities[p.id] = q - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$q',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => quantities[p.id] = q + 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${q * p.price}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    await widget.store.saveDistribution(
      customerId: widget.customer.id,
      date: DateTime.now(),
      quantities: quantities,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Distribution saved successfully')),
    );
    Navigator.pop(context);
  }
}

class MonthlySelectScreen extends StatelessWidget {
  final AppStore store;
  const MonthlySelectScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Billing')),
      body: AnimatedBuilder(
        animation: store,
        builder: (_, __) => ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: store.customers.length,
          itemBuilder: (_, index) {
            final c = store.customers[index];
            final total = store.monthTotal(c.id, DateTime.now());
            return Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text('${c.id} • ${c.name}'),
                subtitle: Text(
                  '${store.monthPouches(c.id, DateTime.now())} pouches this month',
                ),
                trailing: Text(
                  '₹$total',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MonthlyBillScreen(store: store, customer: c),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class MonthlyBillScreen extends StatelessWidget {
  final AppStore store;
  final Customer customer;

  const MonthlyBillScreen({
    super.key,
    required this.store,
    required this.customer,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final entries = <Map<String, dynamic>>[];

    for (final d in store.distributions) {
      if (d.customerId != customer.id) continue;
      final parts = d.date.split('-');
      if (parts.length != 3) continue;
      if (int.tryParse(parts[0]) != now.year ||
          int.tryParse(parts[1]) != now.month) {
        continue;
      }

      for (final e in d.quantities.entries) {
        if (e.value <= 0) continue;
        final p = productById(e.key);
        if (p == null) continue;
        entries.add({
          'date': d.date,
          'product': p.name,
          'qty': e.value,
          'amount': e.value * p.price,
        });
      }
    }

    final total = entries.fold<int>(
      0,
      (sum, row) => sum + row['amount'] as int,
    );
    final pouches = entries.fold<int>(
      0,
      (sum, row) => sum + row['qty'] as int,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Bill')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${customer.id} • ${customer.mobile}'),
                  Text(customer.address),
                  const Divider(height: 24),
                  Text('Month: ${now.month}/${now.year}'),
                  Text('Total Pouches: $pouches'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No distribution entries this month')),
              ),
            )
          else
            for (final row in entries)
              Card(
                child: ListTile(
                  title: Text(row['product'] as String),
                  subtitle:
                      Text('${row['date']} • ${row['qty']} pouch × rate'),
                  trailing: Text(
                    '₹${row['amount']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Card(
            color: const Color(0xFFE7F3F5),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MONTHLY TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₹$total',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
