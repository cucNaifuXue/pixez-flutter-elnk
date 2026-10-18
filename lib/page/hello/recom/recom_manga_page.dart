import 'package:material_ui/material_ui.dart';
import 'package:pixez/lighting/lighting_page.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/network/api_client.dart';

class RecomMangaPage extends StatefulWidget {
  const RecomMangaPage({super.key});

  @override
  State<RecomMangaPage> createState() => _RecomMangaPageState();
}

class _RecomMangaPageState extends State<RecomMangaPage> {
  late final ApiSource _source;

  @override
  void initState() {
    super.initState();
    _source = ApiSource(futureGet: () => apiClient.getMangaRecommend());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manga')),
      body: LightingList(source: _source),
    );
  }
}
