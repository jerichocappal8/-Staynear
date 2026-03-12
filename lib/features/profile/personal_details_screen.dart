import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:staynear/core/app_colors.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _emailController = TextEditingController();

  String? _selectedCity;
  String? _selectedBarangay;

  bool _isLoading = true;
  bool _isSaving = false;

  static const String _fixedProvince = 'Pangasinan';

  static const List<String> _cities = [
    'Agno', 'Aguilar', 'Alaminos City', 'Alcala', 'Anda', 'Asingan',
    'Balungao', 'Bani', 'Basista', 'Bautista', 'Bayambang', 'Binalonan',
    'Binmaley', 'Bolinao', 'Bugallon', 'Burgos', 'Calasiao', 'Dagupan City',
    'Dasol', 'Infanta', 'Labrador', 'Laoac', 'Lingayen', 'Mabini',
    'Malasiqui', 'Manaoag', 'Mangaldan', 'Mangatarem', 'Mapandan',
    'Natividad', 'Pozorrubio', 'Rosales', 'San Carlos City', 'San Fabian',
    'San Jacinto', 'San Manuel', 'San Nicolas', 'San Quintin', 'Santa Barbara',
    'Santa Maria', 'Santo Tomas', 'Sison', 'Sual', 'Tayug', 'Umingan',
    'Urbiztondo', 'Urdaneta City', 'Villasis',
  ];

  static const Map<String, List<String>> _barangaysByCity = {
    'Agno': ['Allawig', 'Ambalayat', 'Bangan-Oda', 'Batiarao', 'Cayungnan', 'Danley', 'Estanza', 'Inoman', 'Laoac', 'Malabobo', 'Malibong', 'Patar', 'Poblacion East', 'Poblacion West', 'Sula', 'Tara', 'Tupa', 'Viga'],
    'Aguilar': ['Bayaoas', 'Baybay', 'Bocacliw', 'Bocboc East', 'Bocboc West', 'Buer', 'Caoayan-Corpuz', 'Cobol', 'Coliling', 'Estanza', 'Lasip', 'Mabini', 'Macarang', 'Malabago', 'Navaluan', 'Pias', 'Poblacion Norte', 'Poblacion Sur', 'Rongos', 'Salay', 'Talogtog', 'Tanauan', 'Vacante', 'Villanueva'],
    'Alaminos City': ['Alos', 'Amandiego', 'Amangbangan', 'Balangobong', 'Balayang', 'Bisocol', 'Bolaney', 'Bued', 'Cabatuan', 'Cayucay', 'Dulacac', 'Inerangan', 'Landoc', 'Linmansangan', 'Lucap', 'Mabilao', 'Namagbagan', 'Parian', 'Payas', 'Payocpoc Norte Este', 'Payocpoc Norte Oeste', 'Payocpoc Sur', 'Pogo', 'Polo', 'Quibuar', 'Sabangan', 'San Antonio', 'San Jose', 'San Roque', 'San Vicente', 'Santa Maria', 'Tanaytay', 'Tangcarang', 'Telbang', 'Tiblong', 'Tococ East', 'Tococ West', 'Tondol', 'Toritori', 'Tugui Grande', 'Tugui Norte'],
    'Alcala': ['Abot', 'Alinggan', 'Amampeque', 'Baracbac East', 'Baracbac West', 'Caabiangan', 'Cabilaoan West', 'Calaoaan', 'Carayungan Sur', 'Carayungan Norte', 'Casantaan', 'Cawayan', 'Cayambanan', 'Cula', 'Dilan-Paurido', 'Duat', 'Guiling', 'Ilang', 'Lelemaan', 'Licicap', 'Macayug', 'Magtaking', 'Malibong East', 'Malibong West', 'Manambong Norte', 'Manambong Parte', 'Manambong Sur', 'Nancalabasaan', 'Nancayasan', 'Olea', 'Palaris', 'Palospos', 'Pao', 'Papaya', 'Poblacion', 'Pugaro', 'San Isidro', 'San Nicolas', 'San Pablo', 'San Vicente', 'Sapang Biabas', 'Sonquil', 'Tado', 'Talogtog', 'Tobuan', 'Tococ'],
    'Anda': ['Awile', 'Baleyadaan', 'Bannaay East', 'Bannaay West', 'Bolaoen', 'Imelda', 'Lipit Norte', 'Lipit Sur', 'Lomboy', 'Lucap', 'Poblacion', 'Tondol', 'Toritori'],
    'Asingan': ['Ariston Este', 'Ariston Weste', 'Bantog', 'Bobonan', 'Cabalitian', 'Calepaan', 'Calosoan', 'Camangaan', 'Canarvacanan', 'Capulaan', 'Caramutan', 'Carbanaan', 'Cayambanan', 'Dorongan Ketabian', 'Dorongan Punta', 'Dorongan Valerio', 'Fuentes', 'Guilig', 'Inlaud', 'Langiran', 'Ligue', 'Losong Banuar', 'Losong Singalan', 'Macayug', 'Magsaysay', 'Maguiling', 'Malasil', 'Malimpec', 'Malpitic', 'Mamarlao', 'Mandac', 'Manggan-Dampay', 'Nancalobasaan', 'Nancayasan', 'Nansangaan', 'Olea', 'Palina', 'Poblacion', 'Pugaro', 'San Antonio', 'San Isidro', 'San Jose', 'San Nicolas', 'San Roque', 'San Vicente', 'Santa Catalina', 'Santa Lucia', 'Santa Maria', 'Santo Domingo', 'Sapang', 'Tobuan', 'Warding', 'Zafarancho'],
    'Balungao': ['Angayan Norte', 'Angayan Sur', 'Balancanaway', 'Baloling', 'Bantog', 'Bolaoen', 'Buayaen', 'Buenlag', 'Cabayaoan', 'Caranglaan', 'Guiset Norte', 'Guiset Sur', 'Laruan', 'Lasip', 'Lipa', 'Longos', 'Nancamaliran West', 'Nansangaan', 'Olo Cacamposan', 'Olo Cafabrosan', 'Olo Cagarlitan', 'Pacalat', 'Pindangan', 'Poblacion', 'Pugal', 'Pugo', 'Reynado', 'San Andres', 'San Francisco', 'San Jose', 'San Marcos', 'Santo Tomas', 'Talogtog', 'Tebeng'],
    'Bani': ['Amandiego', 'Amangbangan', 'Balangobong', 'Balayang', 'Bisocol', 'Bolaney', 'Bued', 'Cabatuan', 'Cayucay', 'Dulacac', 'Inerangan', 'Landoc', 'Linmansangan', 'Lucap', 'Mabilao', 'Parian', 'Payas', 'Pogo', 'Polo', 'San Antonio', 'San Jose', 'San Roque', 'San Vicente', 'Santa Maria', 'Tondol'],
    'Basista': ['Bacnono', 'Balaya', 'Balaybuaya', 'Banaban', 'Bancal', 'Bañaga', 'Bateng', 'Bobonan', 'Calsib', 'Camangaan', 'Canarvacanan', 'Caoayan', 'Caranglaan', 'Cardis', 'Carmay East', 'Carmay West', 'Catablan', 'Cayambanan', 'Coliling', 'Doyong', 'Gueguesangen', 'Inlaud', 'Lasip', 'Longos', 'Macayug', 'Mamarlao', 'Nancamaliran East', 'Nancamaliran West', 'Nancayasan', 'Nansangaan', 'Niño Jesus', 'Olea', 'Palina', 'Poblacion', 'Pugaro', 'San Antonio', 'San Isidro', 'San Jose', 'San Roque', 'San Vicente', 'Santa Catalina', 'Santo Domingo', 'Tobuan'],
    'Bautista': ['Artacho', 'Balungao', 'Bugayong', 'Cabalitian', 'Camaley', 'Canarvacanan', 'Caoayan', 'Caranglaan', 'Gueguesangen', 'Inlaud', 'Laoac', 'Macayug', 'Mabini', 'Magtaking', 'Malpitic', 'Mancup', 'Nancamaliran East', 'Nancamaliran West', 'Nancayasan', 'Olea', 'Palina', 'Poblacion', 'San Isidro', 'San Jose', 'San Vicente', 'Tobuan'],
    'Bayambang': ['Abot', 'Alo-o', 'Ambayoan', 'Apalen', 'Aponit', 'Bacnono', 'Balaybuaya', 'Banaban', 'Bancal', 'Bateng', 'Bical Norte', 'Bical Sur', 'Bongalon', 'Buenlag', 'Bugayong', 'Camangaan', 'Canarvacanan', 'Capas', 'Caquiputan', 'Caturay', 'Danley', 'Dilan-Paurido', 'Gueguesangen', 'Guing-Guing', 'Guisit', 'Inosan', 'Langiran', 'M. H. del Pilar', 'Macayug', 'Malimpec', 'Managosing', 'Nancalobasaan', 'Nancamaliran East', 'Nancamaliran West', 'Nancayasan', 'Niño Jesus', 'Olea', 'Palina East', 'Palina West', 'Palo Maria', 'Pangalangan', 'Patpata Grande', 'Patpata Munti', 'Poblacion Este', 'Poblacion Norte', 'Poblacion Oeste', 'Poblacion Sur', 'Pugaro', 'Resurreccion', 'San Fabian', 'San Felipe', 'San Isidro', 'San Jose', 'San Leon', 'San Manuel', 'San Pablo', 'San Pedro', 'San Roque', 'San Vicente', 'Sapang', 'Tobuan', 'Yamot'],
    'Binalonan': ['Amistad', 'Ara', 'Asin Este', 'Asin Oeste', 'Austine', 'Bano', 'Bobonan', 'Cabalitian', 'Calepaan', 'Calosoan', 'Camangaan', 'Canarvacanan', 'Caoayan', 'Capulaan', 'Caramutan', 'Carbanaan', 'Cayambanan', 'Dorongan Ketabian', 'Dorongan Punta', 'Dorongan Valerio', 'Fuentes', 'Guilig', 'Inlaud', 'Langiran', 'Ligue', 'Losong Banuar', 'Losong Singalan', 'Macayug', 'Magsaysay', 'Maguiling', 'Malasil', 'Malimpec', 'Malpitic', 'Moreno', 'Mandac', 'Manggan-Dampay', 'Nancalobasaan', 'Nancayasan', 'Nansangaan', 'Olea', 'Palina', 'Poblacion', 'Pugaro', 'San Antonio', 'San Isidro', 'San Jose', 'San Nicolas', 'San Roque', 'San Vicente', 'Santa Catalina', 'Santa Lucia', 'Santa Maria', 'Santo Domingo', 'Sapang', 'Tobuan', 'Warding', 'Zafarancho'],
    'Binmaley': ['Amancoro', 'Balagan', 'Balogo', 'Basing', 'Baugusto T. Fernandez Sr.', 'Buenlag 1st', 'Buenlag 2nd', 'Calit', 'Caloocan Norte', 'Caloocan Sur', 'Camaley', 'Canaoay', 'Cayanga', 'Colonel Corpus', 'Coral', 'Dagupan', 'Dalangiring', 'Daly', 'Davarte', 'Gayaman', 'Ican', 'Linoc', 'Lomboy', 'Nagpalangan', 'Naguilayan', 'Pallas', 'Papagueyan', 'Parayao', 'Poblacion', 'Pototan', 'Sabangan', 'Salapingao', 'San Isidro Norte', 'San Isidro Sur', 'San Vicente', 'Tombor'],
    'Bolinao': ['Arnedo', 'Balingasay', 'Binabalian', 'Cabuyao', 'Catuday', 'Cayangan', 'Concordia Sur', 'Culang', 'Dewey', 'Estanza', 'Germinal', 'Goyoden', 'Ilogmalino', 'Lauit', 'Lucero', 'Luciente 1st', 'Luciente 2nd', 'Luna', 'Mabini', 'Macato', 'Malibong', 'Patar', 'Pilar', 'Poblacion', 'Poc-ac', 'Samang Norte', 'Samang Sur', 'Sampaloc', 'Santiago', 'Tara', 'Tomas Bugallon', 'Tortosa', 'Victory', 'Zaragoza'],
    'Bugallon': ['Abendan', 'Ampid', 'Anonang Norte', 'Anonang Sur', 'Aramal', 'Bacnono', 'Barlo', 'Caoayan-Corpuz', 'Cobol', 'Coliling', 'Ican', 'Labangan Camantiles', 'Labangan Labit', 'Labangan Lipit', 'Lasip', 'Libsong', 'Mabalbalino', 'Macayug', 'Malibong', 'Manat', 'Nangalasaan', 'Niño Jesus', 'Oaig-Daya', 'Oaig-Ubing', 'Padlaen', 'Palauig', 'Patpata Grande', 'Patpata Munti', 'Poblacion Norte', 'Poblacion Sur', 'Pugaro', 'Pugo', 'Reynado', 'Sabangan', 'Salinap', 'San Fabian', 'San Felipe', 'San Isidro', 'San Jose', 'San Leon', 'San Pablo', 'San Pedro', 'San Roque', 'San Vicente', 'Saraqueb', 'Tobuan', 'Tubig-Salinas'],
    'Burgos': ['Babuyan', 'Batac', 'Bobonan', 'Bued', 'Buenlag', 'Bueno', 'Bugallon', 'Cabalitian', 'Calepaan', 'Calosoan', 'Camangaan', 'Canarvacanan', 'Coliling', 'Dorongan Ketabian', 'Dorongan Punta', 'Dorongan Valerio', 'Dueg', 'Guilig', 'Langiran', 'Losong', 'Macayug', 'Magsaysay', 'Malasil', 'Malimpec', 'Malpitic', 'Mamarlao', 'Nancalobasaan', 'Nancayasan', 'Nansangaan', 'Olea', 'Palina', 'Poblacion', 'Pugaro', 'San Antonio', 'San Isidro', 'San Jose', 'San Nicolas', 'San Roque', 'San Vicente', 'Sapang', 'Tobuan'],
    'Calasiao': ['Ambonao', 'Ambuetel', 'Banaoang', 'Bued', 'Buenlag', 'Cabilocaan', 'Dinalaoan', 'Doyong', 'Gabon', 'Lasip', 'Longos', 'Lumbang', 'Macabito', 'Malabago', 'Mancup', 'Nagsaing', 'Nalsian Norte', 'Nalsian Sur', 'Poblacion East', 'Poblacion West', 'Quesban', 'San Miguel', 'San Vicente', 'Songkoy', 'Talibaew'],
    'Dagupan City': ['Bacayao Norte', 'Bacayao Sur', 'Barangay I (Pob.)', 'Barangay II (Pob.)', 'Barangay III (Pob.)', 'Barangay IV (Pob.)', 'Bolosan', 'Bonuan Binloc', 'Bonuan Boquig', 'Bonuan Gueset', 'Calmay', 'Carael', 'Caranglaan', 'Herrero', 'Lasip Chico', 'Lasip Grande', 'Lomboy', 'Lucao', 'Malued', 'Mamalingling', 'Mangin', 'Mayombo', 'Pantal', 'Poblacion Oeste', 'Pogo Chico', 'Pogo Grande', 'Pugaro Suit', 'Salapingao', 'Salisay', 'Tambac', 'Tapuac', 'Tebeng'],
    'Dasol': ['Alilao', 'Amalbalan', 'Bobonot', 'Eguia', 'Gais-Guipe', 'Hermosa', 'Maasin', 'Macaleeng', 'Macandocandong', 'Mal-ig', 'Malacapas', 'Malibong', 'Palauig', 'Pita', 'Poblacion', 'Polong Norte', 'Polong Sur', 'San Vicente', 'Tambac', 'Tambobong', 'Telbang', 'Tococ'],
    'Infanta': ['Batangbatan', 'Bayambang', 'Buenlag', 'Cabayaoasan', 'Cabilocaan', 'Carapitan', 'Cayanga', 'Darigayos', 'Libsong', 'Malong', 'Pangpang', 'Pantol', 'Poblacion Norte', 'Poblacion Sur', 'Polong', 'San Pedro', 'Toboy'],
    'Labrador': ['Bani', 'Dulig', 'Laois', 'Lomboy', 'Ponton', 'Poblacion', 'San Pedro', 'Santa Rosa', 'Tobuan', 'Urdaneta'],
    'Laoac': ['Anis', 'Balligi', 'Banaban', 'Bani', 'Batong Dalig', 'Cabayo', 'Cabuyao', 'Calaocan', 'Castillo', 'Dibe', 'Gais', 'Lebueg', 'Magtaking', 'Masaganay', 'Nantangalan', 'Olea', 'Pias', 'Poblacion', 'Pugpug', 'Salomague Norte', 'Salomague Sur', 'Samat', 'San Isidro', 'Sanchez', 'Sapang'],
    'Lingayen': ['Aliwekwek', 'Baay', 'Balangobong', 'Balococ', 'Bantayan', 'Basing', 'Capandanan', 'Domalandan Center', 'Domalandan East', 'Domalandan West', 'Dorongan', 'Dulag', 'Estanza', 'Lasip', 'Libsong East', 'Libsong West', 'Malawa', 'Malimpec', 'Maniboc', 'Matalava', 'Naguelguel', 'Namolan', 'Pangapisan Norte', 'Pangapisan Sur', 'Poblacion', 'Quibaol', 'Rosario', 'Sabangan', 'Talogtog', 'Tonton', 'Tumbar', 'Wawa'],
    'Mabini': ['Bacnono', 'Barlo', 'Caabiangan', 'Cabilocaan', 'Cacalibosoan', 'Cadre Site', 'Cambaly', 'Canarvacanan', 'Caoayan', 'Caranglaan', 'Cardis', 'Carmay East', 'Carmay West', 'Catablan', 'Cayambanan', 'Coliling', 'Ican', 'Inlaud', 'Lasip', 'Malimpec', 'Mancup', 'Nancamaliran East', 'Nancamaliran West', 'Nancayasan', 'Olea', 'Poblacion', 'San Isidro', 'San Jose', 'San Vicente', 'Tobuan'],
    'Malasiqui': ['Alacan', 'Alitaya', 'Ames', 'Anando', 'Anonas', 'Apalen', 'Asin', 'Ataynan', 'Bacnono', 'Bagong Barrio', 'Baguinay', 'Baracbac', 'Batang', 'Binalay', 'Bogtong', 'Bolo', 'Bongato East', 'Bongato West', 'Bued', 'Buenlag', 'Bueno', 'Bugallon', 'Bulak Norte', 'Bulak Sur', 'Bulig', 'Cabayaoasan', 'Cabilocaan', 'Cabuaan', 'Cadre Site', 'Cambaly', 'Caoayan-Corpuz', 'Carayungan Sur', 'Carayungan Norte', 'Casantaan', 'Catablan', 'Cayambanan', 'Comillas Norte', 'Comillas Sur', 'Damortis', 'Dompay', 'Duera', 'Dumpay', 'Estanza', 'Lasip', 'Legu', 'Lioac Norte', 'Lioac Sur', 'Longos', 'Lucao', 'Macayug', 'Magtaking', 'Malbago', 'Mancup', 'Manggan-Dampay', 'Masalasa', 'Maticmatic', 'Minien East', 'Minien West', 'Nagsaing', 'Nalsian Norte', 'Nalsian Sur', 'Nancalobasaan', 'Nancamaliran East', 'Nancamaliran West', 'Nancayasan', 'Niño Jesus', 'Olea', 'Palina Norte', 'Palina Sur', 'Patopat', 'Pias', 'Poblacion', 'Pugaro', 'Pugo', 'Reynado', 'Sabangan', 'Salapingao', 'San Fabian', 'San Felipe', 'San Isidro', 'San Jose', 'San Leon', 'San Manuel', 'San Pablo', 'San Pedro', 'San Roque', 'San Vicente', 'Santa Catalina', 'Santa Cecilia', 'Santa Cruz', 'Santa Lucia', 'Santa Maria', 'Santo Tomas', 'Sapang', 'Talogtog', 'Tobuan', 'Tococ', 'Tombor', 'Vacante', 'Villanueva'],
    'Manaoag': ['Bacnar', 'Baloling', 'Banaol', 'Bani', 'Bilis', 'Binday', 'Bolaoen', 'Buenlag', 'Cabilocaan', 'Calaocan', 'Caramutan', 'Caridad', 'Cayanga', 'Cogon', 'Coliling', 'Damortis', 'Erfe', 'Gueguesangen', 'Herrero', 'Inmalog', 'Inmalog Norte', 'Libsong', 'Licaong', 'Linmansangan', 'Lucao', 'Macarang', 'Malimpec', 'Manaol', 'Nalsian', 'Nancalobasaan', 'Nancamaliran', 'Nancayasan', 'Olea', 'Pantal', 'Partido', 'Piñanes', 'Poblacion', 'Pugaro', 'Pugo', 'Reynado', 'Sabangan', 'Salapingao', 'San Fabian', 'San Isidro', 'San Jose', 'San Pablo', 'San Pedro', 'San Roque', 'San Vicente', 'Saraqueb', 'Sawat', 'Solang', 'Tebeng', 'Tulong', 'Vacante'],
    'Mangaldan': ['Alitaya', 'Amansabina', 'Anolid', 'Apulid', 'Balangobong', 'Barang', 'Bolo', 'Buenlag', 'Cabuloan', 'Calorong', 'Camangaan', 'Careran', 'Carmay East', 'Carmay West', 'Carmen East', 'Carmen West', 'Casantaan', 'Dorongan Ketabian', 'Dorongan Punta', 'Dorongan Valerio', 'Dulag', 'Gueguesangen', 'Inlaud', 'Lasip', 'Longos', 'Manalanggue', 'Nibaliw Central', 'Nibaliw East', 'Nibaliw West', 'Nolasco', 'Osiem', 'Palaris', 'Poblacion', 'Salay', 'Salinap', 'San Isidro Norte', 'San Isidro Sur', 'San Jose', 'San Pablo', 'San Vicente', 'Sobol', 'Talogtog', 'Tamaro', 'Tobuan', 'Vacante'],
    'Mangatarem': ['Andangin', 'Arellano-Navatat', 'Bantayan', 'Baracbac', 'Bolaoen', 'Buenlag', 'Cabaruan', 'Cabayaoasan', 'Cafabrosan', 'Caggao', 'Calaocan Sur', 'Calosoan', 'Camangaan', 'Caoayan', 'Caranglaan', 'Cardis', 'Carmay', 'Casantaan', 'Cayanga', 'Coliling', 'Dilan-Paurido', 'Dunggon', 'Gueguesangen', 'Guilig', 'Ican', 'Inlaud', 'Lasip', 'Longos', 'Lucao', 'Macayug', 'Mambog', 'Mancup', 'Maniboc', 'Nancamaliran East', 'Nancamaliran West', 'Nansangaan', 'Niño Jesus', 'Olea', 'Palina', 'Pantal', 'Poblacion', 'Pugaro', 'San Antonio', 'San Isidro', 'San Jose', 'San Vicente', 'Santo Tomas', 'Sapang', 'Tobuan', 'Toboy'],
    'Mapandan': ['Amanoaoac', 'Apaya', 'Asin Este', 'Asin Weste', 'Cabalaoangan Norte', 'Cabalaoangan Sur', 'Cabaruan', 'Cabayaoasan', 'Cabilocaan', 'Cabuaan', 'Cacaoiten', 'Calaocan', 'Camisetan', 'Canarvacanan', 'Capulaan', 'Caquiputan', 'Casantaan', 'Cayambanan', 'Cobol', 'Coliling', 'Domanpot', 'Dulag', 'Esteban', 'Lasip', 'Macayug', 'Malimpec', 'Malpitic', 'Mamarlao', 'Nancalobasaan', 'Nancamaliran East', 'Nancamaliran West', 'Nancayasan', 'Niño Jesus', 'Olea', 'Palina', 'Pogo', 'Pogoy', 'Poblacion', 'Pugaro', 'Pugo', 'Reynado', 'Sabangan', 'Salapingao', 'San Isidro', 'San Jose', 'San Vicente', 'Santa Catalina', 'Santo Tomas', 'Sapang', 'Talogtog', 'Tobuan', 'Vacante'],
    'Natividad': ['Angayan Norte', 'Angayan Sur', 'Capulaan', 'Caranglaan', 'Flores', 'Macayug', 'Nancamaliran West', 'Nansangaan', 'Poblacion', 'San Andres', 'San Blas', 'San Francisco', 'San Marcus', 'San Miguel', 'San Vicente'],
    'Pozorrubio': ['Alac', 'Apo', 'Arenas', 'Balacag', 'Banding', 'Bantugan', 'Bateng', 'Bobonan', 'Buneg', 'Cablong', 'Casantiagoan', 'Cauyocan', 'Cavorit', 'Dolaoan', 'Inoman', 'Laoac', 'Laoagan', 'Maamot', 'Mabugnao', 'Malabing', 'Malibong', 'Munlat', 'Nantangalan', 'Pacalat', 'Palacpalac', 'Pindangan Norte', 'Pindangan Sur', 'Poblacion', 'Pugo', 'San Felipe', 'San Isidro', 'San Juan', 'San Leon', 'San Pedro', 'Santa Rosa', 'Santo Tomas', 'Sobol', 'Talogtog', 'Tobuan', 'Tulong', 'Vacante'],
    'Rosales': ['Abar', 'Asin', 'Balite', 'Balsain', 'Bantog', 'Bayaoas', 'Bobonan', 'Bued', 'Buenlag', 'Caaringayan', 'Cabilocaan', 'Caingal', 'Calosoan', 'Camangaan', 'Carayungan', 'Carranglaan', 'Casantaan', 'Coliling', 'Dilan-Paurido', 'Dorongan', 'Dueg', 'Dumayat', 'Esmeralda', 'Estanza', 'Inlaud', 'Lasip', 'Ligue', 'Losong', 'Macayug', 'Malabago', 'Malimpec', 'Malpitic', 'Mamarlao', 'Nancamaliran', 'Nansangaan', 'Olea', 'Palina', 'Poblacion', 'Pugaro', 'San Antonio', 'San Isidro', 'San Jose', 'San Roque', 'San Vicente', 'Santa Catalina', 'Sapang', 'Tobuan', 'Umingan'],
    'San Carlos City': ['Agdao', 'Aguilar', 'Alos', 'Balangobong', 'Balococ', 'Bayambang', 'Buenlag', 'Burgos', 'Calsib', 'Camangaan', 'Canarvacanan', 'Capulaan', 'Caranglaan', 'Cardis', 'Carmay', 'Catablan', 'Cayambanan', 'Coliling', 'Cornelio Melecio Sr. (Pob.)', 'Doyong', 'Esmeralda', 'Fernandez', 'Herrero', 'Labit Proper', 'Labit West', 'Lasip', 'Libertad', 'Longos', 'Macayug', 'Magtaking', 'Malabago', 'Malbago', 'Malimpec', 'Malunec', 'Mancup', 'Manggan-Dampay', 'Maniboc', 'Mapulang Daga', 'Matagdem', 'Nagpalangan', 'Naguilayan', 'Nalsian', 'Nancalobasaan', 'Nancamaliran', 'Nansangaan', 'Niño Jesus', 'Osiem', 'Palina', 'Pogo', 'Pogoy', 'Pugaro', 'Pugo', 'Reynado', 'Sabangan', 'Salinap', 'Sampaloc', 'San Antonio', 'San Felipe', 'San Isidro', 'San Jose', 'San Leon', 'San Pablo', 'San Roque', 'San Vicente', 'Santa Catalina', 'Santa Lucia', 'Santa Maria', 'Sapang', 'Saraquit', 'Tobuan', 'Vacante', 'Yamot'],
    'San Fabian': ['Alacan', 'Anonang', 'Asin', 'Bantay', 'Bolasi', 'Cabaruan', 'Cayanga', 'Colayo', 'Damortis', 'Estanza', 'Gueguesangen', 'Inmalog', 'Lasip', 'Lipit Norte', 'Lipit Sur', 'Longos', 'Longos Norte', 'Lucao', 'Magsaysay', 'Nibaliw East', 'Nibaliw West', 'Nibaliw Wakas Norte', 'Nibaliw Wakas Sur', 'Niño Jesus Norte', 'Niño Jesus Sur', 'Olea', 'Palina', 'Poblacion', 'Rabon', 'Salapingao', 'San Pedro', 'Santa Cruz', 'Santo Tomas East', 'Santo Tomas West', 'Seselangen', 'Sison', 'Tobuan', 'Way-a'],
    'San Jacinto': ['Alos', 'Amambangan', 'Baracbac', 'Basing', 'Calaocan Sur', 'Caturay', 'Laoac', 'Macayug', 'Mamalingling', 'Niño Jesus', 'Olea', 'Palina', 'Piñanes', 'Poblacion', 'San Isidro', 'San Vicente', 'Tobuan'],
    'San Manuel': ['Agdao', 'Amanbucal', 'Asin', 'Bantog', 'Bantogon', 'Bueno', 'Caaringayan', 'Cabilocaan', 'Caloocan Norte', 'Caloocan Sur', 'Camangaan', 'Canarvacanan', 'Capulaan', 'Caramutan', 'Carbanaan', 'Casantaan', 'Cayambanan', 'Guilig', 'Inlaud', 'Langiran', 'Losong', 'Macayug', 'Magsaysay', 'Malasil', 'Malimpec', 'Malpitic', 'Mamarlao', 'Mandac', 'Nancalobasaan', 'Nancayasan', 'Nansangaan', 'Olea', 'Palina', 'Poblacion East', 'Poblacion West', 'Pugaro', 'San Antonio', 'San Isidro', 'San Jose', 'San Nicolas', 'San Roque', 'San Vicente', 'Santa Catalina', 'Santa Lucia', 'Sapang', 'Tobuan', 'Zafarancho'],
    'San Nicolas': ['Asin', 'Bobonan', 'Cabalitian', 'Calepaan', 'Calosoan', 'Camangaan', 'Canarvacanan', 'Caoayan', 'Capulaan', 'Caramutan', 'Carbanaan', 'Cayambanan', 'Dorongan Ketabian', 'Dorongan Punta', 'Fuentes', 'Guilig', 'Inlaud', 'Langiran', 'Ligue', 'Macayug', 'Magsaysay', 'Maguiling', 'Malasil', 'Malimpec', 'Malpitic', 'Mamarlao', 'Mandac', 'Nancalobasaan', 'Nancayasan', 'Nansangaan', 'Olea', 'Palina', 'Poblacion', 'Pugaro', 'San Antonio', 'San Isidro', 'San Jose', 'San Roque', 'San Vicente', 'Santa Catalina', 'Santa Lucia', 'Santa Maria', 'Sapang', 'Tobuan', 'Warding'],
    'San Quintin': ['Arabella', 'Balintocatoc', 'Balococ', 'Bantog', 'Capas', 'Carayungan', 'Carranglaan', 'Casantaan', 'Inlaud', 'Magtaking', 'Malimpec', 'Nancamaliran', 'Nansangaan', 'Olea', 'Palina', 'Poblacion', 'Pugaro', 'San Antonio', 'San Isidro', 'San Jose', 'San Roque', 'San Vicente', 'Santa Catalina', 'Tobuan'],
    'Santa Barbara': ['Alibago', 'Balongbong', 'Bañaga', 'Bisocol', 'Buenlag', 'Bued', 'Bueno', 'Bugallon', 'Cabaruan', 'Cabilocaan', 'Cabuloan', 'Cacarongan', 'Cayambanan', 'Coliling', 'Doyong', 'Estanza', 'Gueguesangen', 'Inlaud', 'Lasip', 'Macayug', 'Magsaysay', 'Malimpec', 'Mamarlao', 'Nancamaliran', 'Nancayasan', 'Nansangaan', 'Olea', 'Palina', 'Poblacion Norte', 'Poblacion Sur', 'Pugaro', 'San Antonio', 'San Isidro', 'San Jose', 'San Roque', 'San Vicente', 'Santa Catalina', 'Santo Tomas', 'Sapang', 'Tobuan'],
    'Santa Maria': ['Agguy', 'Balite', 'Bantay', 'Bantog', 'Bautista', 'Bobonan', 'Cadre Site', 'Caoayan-Corpuz', 'Dilan-Paurido', 'Inmalog', 'Lasip', 'Macayug', 'Magtaking', 'Malimpec', 'Mamarlao', 'Nancamaliran', 'Nansangaan', 'Niño Jesus', 'Olea', 'Palina', 'Poblacion', 'San Antonio', 'San Isidro', 'San Jose', 'San Roque', 'San Vicente', 'Santa Catalina', 'Sapang', 'Tobuan'],
    'Santo Tomas': ['Abot', 'Asin', 'Balaybuaya', 'Banaban', 'Baning', 'Bantay', 'Basing', 'Bobonan', 'Bueno', 'Cadre Site', 'Caoayan', 'Caranglaan', 'Casantaan', 'Dilan-Paurido', 'Guilig', 'Inlaud', 'Langiran', 'Lasip', 'Losong', 'Macayug', 'Malimpec', 'Mamarlao', 'Nancalobasaan', 'Nancamaliran East', 'Nancamaliran West', 'Nancayasan', 'Nansangaan', 'Olea', 'Palina', 'Poblacion', 'San Andres', 'San Isidro', 'San Jose', 'San Roque', 'San Vicente', 'Santa Catalina', 'Sapang', 'Tobuan', 'Umingan'],
    'Sison': ['Agat', 'Alibago', 'Alos', 'Bano', 'Bantay', 'Bantog', 'Batac', 'Bintuan', 'Bobonan', 'Buenlag', 'Caabiangan', 'Cabilocaan', 'Cabuyao', 'Cacarongan', 'Cadre Site', 'Caladcad', 'Calaocan', 'Camangaan', 'Caoayan', 'Caranglaan', 'Carpintero', 'Casantaan', 'Dalumpinas Norte', 'Dalumpinas Sur', 'Dilan-Paurido', 'Inabaan Norte', 'Inabaan Sur', 'Inmalog', 'Laoac', 'Lasip', 'Lioac Norte', 'Lioac Sur', 'Macayug', 'Malimpec', 'Mamarlao', 'Nancamaliran East', 'Nancamaliran West', 'Nansangaan', 'Olea', 'Palina', 'Pangan-an', 'Pillilla', 'Pob. Oeste', 'Poblacion', 'Pugaro', 'San Isidro', 'San Jose', 'San Vicente', 'Tobuan'],
    'Sual': ['Baquioen', 'Barrientos', 'Batongko', 'Bolo', 'Bued', 'Buenlag', 'Cacarongan', 'Caloocan', 'Camangaan', 'Cayambanan', 'Coliling', 'Labayug', 'Longos', 'Lucao', 'Macayug', 'Malioer', 'Mancup', 'Nalsian', 'Nancamaliran', 'Niño Jesus', 'Olea', 'Pantal', 'Parsolingan', 'Patpata Grande', 'Patpata Munti', 'Poblacion', 'Pugaro', 'San Andres', 'San Isidro', 'San Jose', 'San Vicente', 'Sto. Tomas', 'Tobuan', 'Tondol'],
    'Tayug': ['Agno', 'Alos', 'Ambalayat', 'Balangobong', 'Balite', 'Banaban', 'Bantog', 'Bantogon', 'Bantay', 'Bayaoas', 'Bobonan', 'Bued', 'Buenlag', 'Caaringayan', 'Cabilocaan', 'Cabuloan', 'Cacarongan', 'Cadre Site', 'Calapugan', 'Camangaan', 'Canarvacanan', 'Capulaan', 'Caramutan', 'Carbanaan', 'Casantaan', 'Cayambanan', 'Coliling', 'Dilan-Paurido', 'Gueguesangen', 'Guilig', 'Inlaud', 'Langiran', 'Lasip', 'Ligue', 'Losong', 'Macayug', 'Magsaysay', 'Malasil', 'Malimpec', 'Malpitic', 'Mamarlao', 'Mandac', 'Nancalobasaan', 'Nancayasan', 'Nansangaan', 'Olea', 'Palina', 'Piñanes', 'Poblacion', 'Pugaro', 'San Antonio', 'San Isidro', 'San Jose', 'San Nicolas', 'San Roque', 'San Vicente', 'Santa Catalina', 'Santa Lucia', 'Santa Maria', 'Sapang', 'Tobuan'],
    'Umingan': ['Abot', 'Alo-o', 'Ambayoan', 'Apalen', 'Aponit', 'Atab', 'Baguinay', 'Balite Norte', 'Balite Sur', 'Bantog', 'Bantogon', 'Batengbatengan', 'Bobonan', 'Buenlag', 'Caabiangan', 'Cabuyao', 'Cadre Site', 'Calapugan', 'Camangaan', 'Canarvacanan', 'Capulaan', 'Caramutan', 'Casantaan', 'Cayambanan', 'Coliling', 'Dalan', 'Dilan-Paurido', 'Gueguesangen', 'Guilig', 'Inlaud', 'Kita-Kita', 'Langiran', 'Lasip', 'Ligue', 'Losong', 'Macayug', 'Magsaysay', 'Malasil', 'Malimpec', 'Malpitic', 'Mamarlao', 'Mandac', 'Nancalobasaan', 'Nancayasan', 'Nansangaan', 'Olea', 'Pacalat', 'Palina', 'Piñanes', 'Poblacion', 'Pugaro', 'San Antonio', 'San Isidro', 'San Jose', 'San Nicolas', 'San Roque', 'San Vicente', 'Santa Catalina', 'Santa Lucia', 'Santa Maria', 'Sapang', 'Tobuan'],
    'Urbiztondo': ['Angatel', 'Balangobong', 'Balayang', 'Baloling', 'Bantayan', 'Basing', 'Bocboc East', 'Bocboc West', 'Bued', 'Buenlag', 'Cabaruan', 'Cabayaoasan', 'Cabroan', 'Cabuloan', 'Cacarongan', 'Cadre Site', 'Calsib', 'Camangaan', 'Canarvacanan', 'Capulaan', 'Caramutan', 'Cardis', 'Casantaan', 'Cayambanan', 'Coliling', 'Damortis', 'Doyong', 'Dulag', 'Estanza', 'Gueguesangen', 'Guilig', 'Inlaud', 'Langiran', 'Lasip', 'Ligue', 'Macayug', 'Magsaysay', 'Malasil', 'Malimpec', 'Malpitic', 'Mamarlao', 'Mandac', 'Nancalobasaan', 'Nancayasan', 'Nansangaan', 'Niño Jesus', 'Olea', 'Palina', 'Poblacion Norte', 'Poblacion Sur', 'Pugaro', 'San Antonio', 'San Isidro', 'San Jose', 'San Nicolas', 'San Roque', 'San Vicente', 'Santa Catalina', 'Santa Lucia', 'Santa Maria', 'Sapang', 'Tobuan'],
    'Urdaneta City': [
      'Anonas', 'Bactad East', 'Bactad Proper', 'Bayaoas', 'Bolaoen',
      'Cabaruan', 'Cabuloan', 'Camanggaan', 'Camantiles', 'Casantaan',
      'Catablan', 'Cayambanan', 'Consolacion', 'Dilan-Paurido',
      'Inmalog Norte', 'Inmalog Sur', 'Labit Proper', 'Labit West',
      'Macalong', 'Nancalobasaan', 'Nancamaliran East', 'Nancamaliran West',
      'Nancayasan', 'Oltama', 'Palina East', 'Palina West', 'Pinmaludpod',
      'Poblacion', 'San Jose', 'San Manuel', 'San Vicente', 'Santa Lucia',
      'Santo Domingo', 'Sugcong', 'Tipayac', 'Tulong',
    ],
    'Villasis': ['Amampeque', 'Bacag', 'Barangobong', 'Barraca', 'Capulaan', 'Caramutan', 'La Paz', 'Labit', 'Licsi', 'Macalong', 'Nancalobasaan', 'Nancamaliran East', 'Nancamaliran West', 'Nancayasan', 'Oaig-Daya', 'Oaig-Ubing', 'Pias', 'Puelay', 'Punglo', 'San Blas', 'San Nicolas', 'Santa Catalina', 'Santa Lucia', 'Santa Rosa', 'Tombor', 'Unzad'],
  };

  List<String> get _currentBarangays {
    if (_selectedCity == null) return [];
    return _barangaysByCity[_selectedCity] ?? [];
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.pop(context);
        return;
      }

      _emailController.text = user.email ?? '';

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _firstNameController.text = data['firstName'] ?? '';
        _middleNameController.text = data['middleName'] ?? '';
        _lastNameController.text = data['lastName'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _streetController.text = data['street'] ?? '';
        _zipCodeController.text = data['zipCode'] ?? '';

        final savedCity = data['city'] ?? '';
        final savedBarangay = data['barangay'] ?? '';

        _selectedCity = _cities.contains(savedCity) ? savedCity : null;
        final barangaysForCity = _barangaysByCity[_selectedCity] ?? [];
        _selectedBarangay = barangaysForCity.contains(savedBarangay) ? savedBarangay : null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'firstName': _firstNameController.text.trim(),
        'middleName': _middleNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'street': _streetController.text.trim(),
        'barangay': _selectedBarangay ?? '',
        'city': _selectedCity ?? '',
        'province': _fixedProvince,
        'zipCode': _zipCodeController.text.trim(),
      }, SetOptions(merge: true));

      if (!mounted) return;

showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    title: const Text("Success"),
    content: const Text("Your personal details were saved successfully."),
    actions: [
      TextButton(
        onPressed: () {
          Navigator.pop(context); // close dialog
          Navigator.pop(context); // go back to Profile screen
        },
        child: const Text("OK"),
      ),
    ],
  ),
);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _zipCodeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, {IconData? icon, bool disabled = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
  color: disabled ? AppColors.textLight : AppColors.textMid,
  fontSize: 14,
  fontWeight: FontWeight.w400,
),
prefixIcon: icon != null
    ? Icon(
        icon,
        size: 18,
        color: disabled ? AppColors.textLight : AppColors.textMid,
      )
    : null,
filled: true,
fillColor: disabled
    ? AppColors.card(context)
    : AppColors.card(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _sectionGroup({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Personal Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange, strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    _sectionLabel('FULL NAME'),
                    _sectionGroup(children: [
                      TextFormField(
                        controller: _firstNameController,
                        style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                        decoration: _fieldDecoration('First Name'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'First name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _middleNameController,
                        style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                        decoration: _fieldDecoration('Middle Name (optional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lastNameController,
                        style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                        decoration: _fieldDecoration('Last Name'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Last name is required' : null,
                      ),
                    ]),

                    const SizedBox(height: 24),

                    _sectionLabel('CONTACT INFORMATION'),
                    _sectionGroup(children: [
                      TextFormField(
                        controller: _phoneController,
                        style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                        decoration: _fieldDecoration('Phone Number', icon: Icons.phone_outlined),
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Phone number is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        enabled: false,
                        style: const TextStyle(fontSize: 14, color: AppColors.textLight),
                        decoration: _fieldDecoration('Email Address',
                            icon: Icons.email_outlined, disabled: true),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    _sectionLabel('ADDRESS'),
                    _sectionGroup(children: [

                      // Street
                      TextFormField(
                        controller: _streetController,
                        style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                        decoration: _fieldDecoration('Street / House No.',
                            icon: Icons.home_outlined),
                        maxLines: null,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Street is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Province — fixed, read-only
                      TextFormField(
                        initialValue: _fixedProvince,
                        enabled: false,
                        style: const TextStyle(fontSize: 14, color: AppColors.textLight),
                        decoration: _fieldDecoration('Province',
                            icon: Icons.map_outlined, disabled: true),
                      ),
                      const SizedBox(height: 12),

                      // City — Pangasinan cities dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCity,
                        decoration: _fieldDecoration('City / Municipality'),
                        style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                        dropdownColor: AppColors.card(context),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textMid, size: 20),
                        isExpanded: true,
                        items: _cities
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) => setState(() {
                          _selectedCity = val;
                          _selectedBarangay = null;
                        }),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'City is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Barangay — dynamic based on selected city
                      DropdownButtonFormField<String>(
                        value: _selectedBarangay,
                        decoration: _fieldDecoration(
                          _selectedCity == null
                              ? 'Barangay (select city first)'
                              : 'Barangay',
                        ),
                        style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                        dropdownColor: AppColors.cardWhite,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textMid, size: 20),
                        isExpanded: true,
                        disabledHint: Text(
                          'Select a city first',
                          style: TextStyle(fontSize: 14, color: AppColors.textLight),
                        ),
                        items: _currentBarangays.isEmpty
                            ? null
                            : _currentBarangays
                                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                .toList(),
                        onChanged: _currentBarangays.isEmpty
                            ? null
                            : (val) => setState(() => _selectedBarangay = val),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Barangay is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Zip Code — text field, numbers only
                      TextFormField(
                        controller: _zipCodeController,
                        style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                        decoration: _fieldDecoration('Zip Code',
                            icon: Icons.markunread_mailbox_outlined),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Zip code is required' : null,
                      ),
                    ]),

                    const SizedBox(height: 32),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFFFD580),
                          elevation: 2,
                          shadowColor: AppColors.primaryOrange.withOpacity(0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _isSaving
                              ? const SizedBox(
                                  key: ValueKey('loading'),
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  key: ValueKey('label'),
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}