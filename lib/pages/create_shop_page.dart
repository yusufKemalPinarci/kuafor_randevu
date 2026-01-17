import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/shop_model.dart';
import '../models/user_model.dart';
import '../providers/shop_provider.dart';
import '../providers/user_provider.dart';
import '../services/address_service.dart';
import '../services/shop_service.dart';

class CreateShopPage extends StatefulWidget {
  @override
  _CreateShopPageState createState() => _CreateShopPageState();
}

class _CreateShopPageState extends State<CreateShopPage> {
  final _formKey = GlobalKey<FormState>();
  final AddressService _addressService = AddressService();
  final ShopService _shopService = ShopService();


  String? _shopName;
  String? _address;
  int? _selectedProvinceId;
  Map? _selectedDistrictId;
  String? _selectedNeighborhoodName;
  String? _selectedProvinceName;
  String? _selectedDistrictName;


  List<dynamic> _provinces = [];
  List<dynamic> _districts = [];
  List<dynamic> _neighborhoods = [];

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<String> _workingDays = [];
  List<String> _employeeEmails = [];
  final TextEditingController _employeeController = TextEditingController();
  String? _shopPhone;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  Future<void> _loadProvinces() async {
    final provinces = await _addressService.getProvinces();
    setState(() {
      _provinces = provinces;
    });
  }

  Future<void> _loadDistricts(int provinceId) async {
    final districts = await _addressService.getDistricts(provinceId);
    setState(() {
      _districts = districts;
      _selectedDistrictId = null;
      _neighborhoods = [];
    });
  }

  Future<void> _loadNeighborhoods(int districtId) async {
    final neighborhoods = await _addressService.getNeighborhoods(districtId);
    setState(() {
      _neighborhoods = neighborhoods;
      _selectedNeighborhoodName = null;
    });
  }

  // İl seçildiğinde
  void onProvinceSelected(int id, String name) async {
    _selectedProvinceId = id;
    _selectedProvinceName = name;
    // ...
  }

// İlçe seçildiğinde
  void onDistrictSelected(int id, String name) async {
   // _selectedDistrictId = id;
   // _selectedDistrictName = name;
    // ...
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _addEmployee() {
    if (_employeeController.text.isNotEmpty) {
      setState(() {
        _employeeEmails.add(_employeeController.text.trim());
        _employeeController.clear();
      });
    }
  }

  void _removeEmployee(String email) {
    setState(() {
      _employeeEmails.remove(email);
    });
  }

  Future<void> _createShop() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);

    final user = userProvider.user;

   // if (!_formKey.currentState!.validate()) return;
    // _formKey.currentState!.save();

    final shopData = {
      "name": _shopName,
      "fullAddress": _address,
      "city": _selectedProvinceName,
      "district": _selectedDistrictName, // ilçe
      "neighborhood": _selectedNeighborhoodName,
      "phone": _shopPhone,
      "adress": _address,
      "openingHour": _startTime?.format(context),
      "closingHour": _endTime?.format(context),
      "workingDays": _workingDays,
      "staffEmails": _employeeEmails,
      "ownerId": user!.id,
    };

    try {
      final response = await _shopService.createShop(shopData, token: user!.jwtToken);

      // Backend shop ve güncel user döndürüyor
      if (response['shop'] != null) {
        final newShop = ShopModel.fromJson(response['shop']);
        await shopProvider.saveShopToLocal(newShop); // Provider + Local kaydet
      }

      if (response['user'] != null) {
        final updatedUser = UserModel.fromJson(response['user']);
        await userProvider.saveUserToLocalAndProvider(updatedUser);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dükkan başarıyla oluşturuldu!")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Dükkan Oluştur")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: "Dükkan Adı"),
                validator: (val) => val!.isEmpty ? "Boş bırakılamaz" : null,
                onSaved: (val) => _shopName = val,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: "Açık Adres"),
                validator: (val) => val!.isEmpty ? "Boş bırakılamaz" : null,
                onSaved: (val) => _address = val,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _selectedProvinceId,
                decoration: const InputDecoration(labelText: "İl Seçiniz"),
                items: _provinces.map((p) {
                  return DropdownMenuItem<int>(
                    value: p["id"],
                    child: Text(p["name"]),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    _selectedProvinceId = val;
                    _loadDistricts(val);
                    final selectedProvince = _provinces.firstWhere((p) => p["id"] == val);
                    onProvinceSelected(val, selectedProvince["name"]);

                  }
                },
              ),
              const SizedBox(height: 12),
          DropdownButtonFormField<Map<String, dynamic>>(
            decoration: const InputDecoration(labelText: "İlçe Seçiniz"),
            items: _districts.map((d) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: d, // Tüm map burada
                child: Text(d["name"]),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                _selectedProvinceName =  val["name"];
               // _selectedDistrictId = val["id"];
                _selectedDistrictName = val["name"]; // Buradan text
                _loadNeighborhoods(val["id"]);
              }
            },
          ),

              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedNeighborhoodName,
                decoration: const InputDecoration(labelText: "Mahalle Seçiniz"),
                items: _neighborhoods.map((n) {
                  return DropdownMenuItem<String>(
                    value: n["name"],
                    child: Text(n["name"]),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedNeighborhoodName = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _selectTime(true),
                      child: Text(
                        _startTime == null
                            ? "Açılış Saati"
                            : _startTime!.format(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _selectTime(false),
                      child: Text(
                        _endTime == null
                            ? "Kapanış Saati"
                            : _endTime!.format(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"
                ].map((day) {
                  final selected = _workingDays.contains(day);
                  return FilterChip(
                    label: Text(day),
                    selected: selected,
                    onSelected: (bool val) {
                      setState(() {
                        if (val) {
                          _workingDays.add(day);
                        } else {
                          _workingDays.remove(day);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Dükkan Telefonu",
                  hintText: "örn: 05551234567",
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return "Boş bırakılamaz";
                  final pattern = RegExp(r'^\+?[0-9]{10,15}$'); // + olabilir, 10-15 hane rakam
                  if (!pattern.hasMatch(val)) return "Geçerli bir telefon numarası girin";
                  return null;
                },
                onSaved: (val) => _shopPhone = val?.trim(),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _employeeController,
                      decoration: const InputDecoration(labelText: "Çalışan E-posta"),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addEmployee,
                  ),
                ],
              ),
              Wrap(
                children: _employeeEmails.map((email) {
                  return Chip(
                    label: Text(email),
                    deleteIcon: const Icon(Icons.close),
                    onDeleted: () => _removeEmployee(email),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _createShop,
                child: const Text("Kaydet"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
