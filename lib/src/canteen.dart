/*
 MIT License

Copyright (c) 2022-2023 Matyáš Caras, tpkowastaken and contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
import 'package:canteenlib/canteenlib.dart';

import 'canteen_versions.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart';

class Canteen {
  /// URL iCanteenu
  String url;

  /// verze iCanteenu
  String? verze;

  /// Instance třídy pro správnou verzi iCanteenu
  Canteen? canteenInstance;

  Canteen(this.url);

  // Je uživatel přihlášen?
  bool get prihlasen => canteenInstance?.prihlasen ?? false;

  String cleanString(String string) {
    return string
        .replaceAll('\n', '')
        .replaceAll('\t', '')
        .replaceAll('\r', '')
        .replaceAll('  ', ' ')
        .replaceAll(' *', '')
        .replaceAll('*', '')
        .trim();
  }

  String parseHtmlString(String htmlString) {
    try {
      final document = parse(htmlString);
      final String parsedString = parse(document.body!.text).documentElement!.text;
      return parsedString;
    } catch (e) {
      return htmlString;
    }
  }

  /// Získá verzi třídy pro verzi icanteenu
  Future<Canteen> _spravovatelVerzi({LoginData? loginData}) async {
    if (verze == null) {
      throw Exception('Nejprve musíte získat verzi iCanteenu');
    }
    switch (verze) {
      case '2.18.03':
        canteenInstance = Canteen_2_18_03(url);
        break;
      case '2.18.19':
        canteenInstance = Canteen_2_18_19(url);
        break;
      case '2.19.13':
        canteenInstance = Canteen_2_19_13(url);
        break;
      default:
        if (loginData == null) {
          //pokud není loginData, tak se nemůže získat verze. Tudíž prostě zkusíme jednu verzi a je možné, že nebude fungovat...
          canteenInstance = Canteen_2_18_19(url);
          break;
        }
        //vyzkoušet všechny verze, dokud se nepodaří přihlášení
        try {
          canteenInstance = Canteen_2_18_19(url);
          await canteenInstance!.login(loginData.username, loginData.password);
          if (!canteenInstance!.prihlasen) {
            throw 'Nepodařilo se přihlásit do iCanteenu';
          }
        } catch (e) {
          try {
            canteenInstance = Canteen_2_19_13(url);
            await canteenInstance!.login(loginData.username, loginData.password);
            if (!canteenInstance!.prihlasen) {
              throw 'Nepodařilo se přihlásit do iCanteenu';
            }
          } catch (e) {
            rethrow;
          }
        }
    }
    if (loginData != null && !canteenInstance!.prihlasen) {
      await canteenInstance!.login(loginData.username, loginData.password);
    }
    return canteenInstance!;
  }

  /// Získá první instanci (případně ji přihlásí) a zjistí verzi
  Future<Canteen> _ziskatInstanciProVerzi({LoginData? loginData}) async {
    //získání verze
    String webHtml = '';
    RegExp versionPattern = RegExp(r'>iCanteen\s\d+\.\d+\.\d+\s\|');
    if (url.contains('https://')) {
      url = url.replaceAll('https://', '');
    }
    if (url.contains('http://')) {
      url = url.replaceAll('http://', '');
    }
    if (url.contains('/')) {
      url = url.substring(0, url.indexOf('/'));
    }
    if (url.contains('@')) {
      url = url.substring(url.indexOf('@') + 1);
    }
    url = 'https://$url';
    try {
      var res = await http.get(Uri.parse(url));
      webHtml = res.body;
    } catch (e) {
      url = url.replaceAll('https://', 'http://');
      var res = await http.get(Uri.parse(url));
      webHtml = res.body;
    }
    Iterable<Match> matches = versionPattern.allMatches(webHtml);
    try {
      String version = matches.first.group(0)!;
      version = version.replaceAll('>iCanteen ', '');
      version = version.replaceAll(' |', '');
      verze = version;
    } catch (e) {
      throw Exception('Nepodařilo se získat verzi iCanteenu');
    }
    //vracení správné verze classy:
    return await _spravovatelVerzi(loginData: loginData);
  }

  /// Přihlášení do iCanteen
  ///
  /// Vstup:
  ///
  /// - `user` - uživatelské jméno | [String]
  /// - `password` - heslo | [String]
  ///
  /// Výstup:
  /// - [bool] ve [Future], v případě přihlášení `true`, v případě špatného hesla `false`
  Future<bool> login(String user, String password) async {
    await _ziskatInstanciProVerzi(loginData: LoginData(user, password));
    return prihlasen;
  }

  /*--------funkce specifické pro verze--------*/

  /// Získá jídelníček bez cen
  /// Tato feature není v prioritě, protože není moc užitečná. Je u ní menší šance, že bude fungovat pokud není v podporovaných verzích.
  ///
  /// Výstup:
  /// - [List] s [Jidelnicek], který neobsahuje ceny
  ///
  /// __Lze použít bez přihlášení__
  Future<List<Jidelnicek>> ziskejJidelnicek() async {
    if (canteenInstance != null) {
      return canteenInstance!.ziskejJidelnicek();
    }
    await _ziskatInstanciProVerzi();
    return canteenInstance!.ziskejJidelnicek();
  }

  /// Získá jídlo pro daný den
  ///
  /// __Vyžaduje přihlášení pomocí [login]__
  ///
  /// Vstup:
  /// - `den` - *volitelné*, určuje pro jaký den chceme získat jídelníček | [DateTime]
  ///
  /// Výstup:
  /// - [Jidelnicek] obsahující detaily, které vidí přihlášený uživatel
  Future<Jidelnicek> jidelnicekDen({DateTime? den}) async {
    if (canteenInstance == null) {
      throw 'nejdříve se musíte přihlásit';
    }
    return canteenInstance!.jidelnicekDen(den: den);
  }

  /// Vrátí informace o uživateli ve formě instance [Uzivatel]
  Future<Uzivatel> ziskejUzivatele() async {
    if (canteenInstance == null) {
      throw 'nejdříve se musíte přihlásit';
    }
    return canteenInstance!.ziskejUzivatele();
  }

  /// Objedná vybrané jídlo
  ///
  /// Vstup:
  /// - `j` - Jídlo, které chceme objednat | [Jidlo]
  ///
  /// Výstup:
  /// - Aktualizovaná instance [Jidlo] tohoto jídla
  Future<Jidlo> objednat(Jidlo j) async {
    if (canteenInstance == null) {
      throw 'nejdříve se musíte přihlásit';
    }
    return canteenInstance!.objednat(j);
  }

  /// Uloží vaše jídlo z/do burzy
  ///
  /// Vstup:
  /// - `j` - Jídlo, které chceme dát/vzít do/z burzy | [Jidlo]
  ///
  /// Výstup:
  /// - Aktualizovaná instance [Jidlo] tohoto jídla NEBO [Future] jako chyba
  Future<Jidlo> doBurzy(Jidlo j, {int amount = 1}) async {
    if (canteenInstance == null) {
      throw 'nejdříve se musíte přihlásit';
    }
    return canteenInstance!.doBurzy(j, amount: amount);
  }

  /// Získá aktuální jídla v burze
  ///
  /// Výstup:
  /// - List instancí [Burza], každá obsahuje informace o jídle v burze
  Future<List<Burza>> ziskatBurzu() async {
    if (canteenInstance == null) {
      throw 'nejdříve se musíte přihlásit';
    }
    return canteenInstance!.ziskatBurzu();
  }

  /// Objedná jídlo z burzy pomocí URL z instance třídy Burza
  ///
  /// Vstup:
  /// - `b` - Jídlo __z burzy__, které chceme objednat | [Burza]
  ///
  /// Výstup:
  /// - [bool], `true`, pokud bylo jídlo úspěšně objednáno z burzy, jinak `Exception`
  Future<bool> objednatZBurzy(Burza b) async {
    if (canteenInstance == null) {
      throw 'nejdříve se musíte přihlásit';
    }
    return canteenInstance!.objednatZBurzy(b);
  }
}
