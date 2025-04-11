import 'dart:convert';
import 'dart:developer';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';

import 'package:msgpack_dart/msgpack_dart.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  State<MainPage> createState() => _MainState();
}

class _MainState extends State<MainPage> {
  final ScrollController _scrollController = ScrollController();

  TextEditingController _inputController = TextEditingController();
  String _contentText = '';
  String _outputText = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();

    _inputController.dispose();
  }

  _decodeData() async {
    // 获取桌面路径（macOS 特定方式）
    // String desktopDir = '/Users/shijianyu/Desktop/ty';

    // // 读取文件路径
    // final pathStr = '$desktopDir/tp_hex_soldier_data.txt';
    // final file = File(pathStr);
    // if (!await file.exists()) {
    //   print('文件不存在: $pathStr');
    //   return;
    // }

    // final pathStr = "lib/resources/tp_hex_soldier_data.txt";
    // final rtfText = await rootBundle.loadString(pathStr);
    // 读取文件内容
    // final rtfText = await file.readAsString();
    final rtfText = _contentText;

    // 提取大段十六进制字符串（连续的 hex 字节）
    final hexPattern = RegExp(r'([0-9a-fA-F]{2}[ \n\r\t\\]*){20,}');
    final match = hexPattern.firstMatch(rtfText);

    if (match == null) {
      print('❌ 未找到十六进制数据');
      _showAlert('数据错误');
      return;
    }

    // 清理并转换 hex 字符串为字节
    final cleanedHex = match.group(0)!.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final bytes = <int>[];
    for (var i = 0; i < cleanedHex.length; i += 2) {
      bytes.add(int.parse(cleanedHex.substring(i, i + 2), radix: 16));
    }

    // 解码 MessagePack
    int offset = 0;
    final buffer = StringBuffer();
    // int count = 0;
    int soldierCapacity = 0;
    List<Map<String, dynamic>> soldiersData = []; // 存储所有士兵数据
    while (offset < bytes.length) {
      try {
        final result = deserialize(Uint8List.fromList(bytes.sublist(offset)));
        final encoded = serialize(result);
        offset += encoded.length;
        // 确保解码结果是 Map 类型
        if (result is Map) {
          print('result: $result');
          var resultJson = jsonEncode(result);

          log('resultJson: $resultJson');

          final datamerge = result['result']['datamerge'];
          soldierCapacity = datamerge['soldierCapacity'];

          if (datamerge != null && datamerge['soldiers'] != null) {
            final soldiers = datamerge['soldiers'];
            soldiers.forEach((key, soldier) {
              // 提取需要的字段
              final level = soldier['level'];
              final quality = soldier['quality'];
              final arm = soldier['arm'];
              final powerQualification = soldier['power_qualification'];
              final physiqueQualification = soldier['physique_qualification'];
              final agileQualification = soldier['agile_qualification'];
              final potentialQualification = soldier['potential_qualification'];
              final basePowerQualification = soldier['base_power'];
              final basePhysiqueQualification = soldier['base_physique'];
              final baseAgileQualification = soldier['base_agile'];
              final basePotentialQualification = soldier['base_potential'];

              final power = soldier['power'];
              final physique = soldier['physique'];
              final agile = soldier['agile'];
              final intelligenct = soldier['intelligenct'];
              final giveCount = soldier['count'];

              // 跳过等级为 1 的士兵
              if (level == 1) return;

              // 新增计算字段 intelligenct_qualification
              double intelligenctQualification = 0;
              if (power != 0) {
                intelligenctQualification =
                    (powerQualification / power) * intelligenct;
              }

              // 颜色映射
              final qualityMapping = {
                'green': '绿',
                'purple': '紫',
                'orange': '橙',
                'blue': '蓝',
              };
              final qualityColor = qualityMapping[quality] ?? '未知';

              // 兵种映射
              final armMapping = {
                'archer': '弓兵',
                'rider': '骑兵',
                'shielder': '盾兵',
                'lancer': '枪兵',
              };
              final armType = armMapping[arm] ?? '未知';

              // 只保存特定的字段
              final extractedData = {
                'level_等级': level,
                'quality_品质': qualityColor,
                'arm_兵种': armType,
                'power_qualification_力量资质': powerQualification,
                'physique_qualification_体质资质': physiqueQualification,
                'agile_qualification_敏捷资质': agileQualification,
                'potential_qualification_潜力资质': potentialQualification,
                '力量资质_初始': basePowerQualification,
                '体质资质_初始': basePhysiqueQualification,
                '敏捷资质_初始': baseAgileQualification,
                '潜力资质_初始': basePotentialQualification,
                'intelligenct_qualification_慧根资质':
                    intelligenctQualification.roundToDouble(),
                'power_力量': power,
                'physique_体质': physique,
                'agile_敏捷': agile,
                'intelligenct_慧根': intelligenct,
                'count_剩余指点次数': giveCount,
              };

              // 添加到士兵数据列表
              soldiersData.add(extractedData);
            });
          } else {
            print('❌ 未找到士兵数据');
          }
        } else {
          print('❌ 解码的结果不是一个有效的 Map 类型');
        }

        // final jsonString = const JsonEncoder.withIndent('  ').convert(result);
        // // buffer.writeln('📦 对象 ${++count}:');
        // // buffer.writeln(jsonString);
        // // buffer.writeln('');
        // if (jsonString.startsWith('{')) {
        //   // buffer.writeln('数据 ${++count}:');
        //   buffer.writeln('士兵数据 : ');
        //   buffer.writeln(jsonString);
        //   buffer.writeln('');
        // }
      } catch (e) {
        print('❌ 解码失败（可能结束或格式不符）: $e');
        break;
      }
    }

    if (soldiersData.isEmpty) {
      print('❌ 未找到士兵数据');
      _showAlert('未找到士兵数据');
      return;
    }

    // 按颜色排序：橙色 -> 紫色 -> 蓝色 -> 绿色
    final colorPriority = {
      '橙': 0,
      '紫': 1,
      '蓝': 2,
      '绿': 3,
    };

    // 对士兵数据进行排序
    soldiersData.sort((a, b) {
      // 获取颜色的排序值
      int? aQuality = colorPriority[a['quality_品质']];
      int? bQuality = colorPriority[b['quality_品质']];

      // 比较颜色排序值
      return aQuality!.compareTo(bQuality!);
    });

    int soldierIndex = 1; // 初始化编号
    // 将排序后的数据转化为字符串
    soldiersData.forEach((data) {
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      buffer.writeln('士兵 ${soldierCapacity}_${soldierIndex++} :'); // ✨ 加上编号
      buffer.writeln(jsonString);
      buffer.writeln('');
    });

    // final timestamp =
    //     DateTime.now().toString().replaceAll(RegExp(r'[^0-9]'), '');
    // final matchRegExp = RegExp(r"ty/([^/_]+)_hex").firstMatch(pathStr);
    // final resultMatch = matchRegExp?.group(1);

    // final outputPath = '$desktopDir/${resultMatch}_士兵数据_$timestamp.txt';
    // final outputFile = File(outputPath);
    // await outputFile.writeAsString(buffer.toString(), flush: true);

    // print('✅ JSON 已保存到桌面: $outputPath');

    _outputText = buffer.toString();
    print('士兵数据: $_outputText');
    _inputController.clear();
    if (mounted) {
      setState(() {
        _inputController.text = _outputText;
      });
    }

    _inputController.selection = TextSelection.collapsed(offset: 0);

    // ✨ 滚动到最顶部
    _scrollController.animateTo(
      0.0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  _showAlert(String content) {
    showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text('提示'),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('确定'),
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('hlsg士兵数据'),
      ),
      body: _mainWidget(),
    );
  }

  _mainWidget() {
    return ListView(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: Color(0xFFB3B3B3),
              width: 0.5,
            ),
          ),
          margin: EdgeInsets.all(10.0),
          child: Padding(
            padding: EdgeInsets.all(10.0),
            child: TextField(
              controller: _inputController,
              scrollController: _scrollController,
              maxLines: 999,
              autofocus: true,
              decoration: InputDecoration.collapsed(
                hintText: '粘贴抓取的HEX数据',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: Color(0xFFB3B3B3),
                ),
              ),
              onChanged: (val) {
                if (mounted) {
                  setState(() {
                    _contentText = val;
                  });
                }
              },
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              width: 150,
              height: 50,
              margin: EdgeInsets.only(top: 10.0),
              child: TextButton(
                child: Text(
                  '转码',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                style: ButtonStyle(
                  padding: MaterialStateProperty.all(
                    EdgeInsets.only(
                      top: 10.0,
                      bottom: 10.0,
                    ),
                  ),
                  shape: MaterialStateProperty.all(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5))),
                  backgroundColor: MaterialStateProperty.all(Colors.blue),
                ),
                onPressed: () {
                  if (_contentText.isEmpty) {
                    _showAlert('请输入数据');
                    return;
                  }
                  _decodeData();
                },
              ),
            ),
            Container(
              width: 150,
              height: 50,
              margin: EdgeInsets.only(top: 10.0),
              child: TextButton(
                child: Text(
                  '清除',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                style: ButtonStyle(
                  padding: MaterialStateProperty.all(
                    EdgeInsets.only(
                      top: 10.0,
                      bottom: 10.0,
                    ),
                  ),
                  shape: MaterialStateProperty.all(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5))),
                  backgroundColor: MaterialStateProperty.all(Colors.red),
                ),
                onPressed: () {
                  _inputController.clear();
                  if (mounted) {
                    setState(() {
                      _contentText = '';
                      _outputText = '';
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
