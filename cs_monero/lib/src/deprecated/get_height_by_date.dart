// TODO/FIXME: Hardcoded values; need to update Monero from 2020-11 on

final moneroDates = {
  "2014-5": 18844,
  "2014-6": 65406,
  "2014-7": 108882,
  "2014-8": 153594,
  "2014-9": 198072,
  "2014-10": 241088,
  "2014-11": 285305,
  "2014-12": 328069,
  "2015-1": 372369,
  "2015-2": 416505,
  "2015-3": 456631,
  "2015-4": 501084,
  "2015-5": 543973,
  "2015-6": 588326,
  "2015-7": 631187,
  "2015-8": 675484,
  "2015-9": 719725,
  "2015-10": 762463,
  "2015-11": 806528,
  "2015-12": 849041,
  "2016-1": 892866,
  "2016-2": 936736,
  "2016-3": 977691,
  "2016-4": 1015848,
  "2016-5": 1037417,
  "2016-6": 1059651,
  "2016-7": 1081269,
  "2016-8": 1103630,
  "2016-9": 1125983,
  "2016-10": 1147617,
  "2016-11": 1169779,
  "2016-12": 1191402,
  "2017-1": 1213861,
  "2017-2": 1236197,
  "2017-3": 1256358,
  "2017-4": 1278622,
  "2017-5": 1300239,
  "2017-6": 1322564,
  "2017-7": 1344225,
  "2017-8": 1366664,
  "2017-9": 1389113,
  "2017-10": 1410738,
  "2017-11": 1433039,
  "2017-12": 1454639,
  "2018-1": 1477201,
  "2018-2": 1499599,
  "2018-3": 1519796,
  "2018-4": 1542067,
  "2018-5": 1562861,
  "2018-6": 1585135,
  "2018-7": 1606715,
  "2018-8": 1629017,
  "2018-9": 1651347,
  "2018-10": 1673031,
  "2018-11": 1695128,
  "2018-12": 1716687,
  "2019-1": 1738923,
  "2019-2": 1761435,
  "2019-3": 1781681,
  "2019-4": 1803081,
  "2019-5": 1824671,
  "2019-6": 1847005,
  "2019-7": 1868590,
  "2019-8": 1890552,
  "2019-9": 1912212,
  "2019-10": 1932200,
  "2019-11": 1957040,
  "2019-12": 1978090,
  "2020-1": 2001290,
  "2020-2": 2022688,
  "2020-3": 2043987,
  "2020-4": 2066536,
  "2020-5": 2090797,
  "2020-6": 2111633,
  "2020-7": 2131433,
  "2020-8": 2153983,
  "2020-9": 2176466,
  "2020-10": 2198453,
  "2020-11": 2220000,
};

final wowneroDates = {
  "2018-5": 8725,
  "2018-6": 17533,
  "2018-7": 25981,
  "2018-8": 34777,
  "2018-9": 43633,
  "2018-10": 52165,
  "2018-11": 60769,
  "2018-12": 66817,
  "2019-1": 72769,
  "2019-2": 78205,
  "2019-3": 84805,
  "2019-4": 93649,
  "2019-5": 102277,
  "2019-6": 111193,
  "2019-7": 119917,
  "2019-8": 128797,
  "2019-9": 137749,
  "2019-10": 146377,
  "2019-11": 155317,
  "2019-12": 163933,
  "2020-1": 172861,
  "2020-2": 181801,
  "2020-3": 190141,
  "2020-4": 199069,
  "2020-5": 207625,
  "2020-6": 216385,
  "2020-7": 224953,
  "2020-8": 233869,
  "2020-9": 242773,
  "2020-10": 251401,
  "2020-11": 260365,
  "2020-12": 269077,
  "2021-1": 278017,
  "2021-2": 286945,
  "2021-3": 295033,
  "2021-4": 303949,
  "2021-5": 312637,
  "2021-6": 321601,
  "2021-7": 330277,
  "2021-8": 340093,
  "2021-9": 349141,
  "2021-10": 357625,
  "2021-11": 366433,
  "2021-12": 374869,
  "2022-1": 383713,
  "2022-2": 392389,
  "2022-3": 400525,
  "2022-4": 409441,
  "2022-5": 417913,
  "2022-6": 426769,
  "2022-7": 435205,
  "2022-8": 444157,
  "2022-9": 453157,
  "2022-10": 461737,
  "2022-11": 470587,
  "2022-12": 479164,
  "2023-1": 488091,
  "2023-2": 497046,
  "2023-3": 504970,
  "2023-4": 513876,
  "2023-5": 522382,
  "2023-6": 531145,
  "2023-7": 539791,
  "2023-8": 548556,
  "2023-9": 557469,
  "2023-10": 565828,
  "2023-11": 574524,
  "2023-12": 583043,
  "2024-1": 591837,
  "2024-2": 600757,
  "2024-3": 608869,
  "2024-4": 617789,
  "2024-5": 626376,
  "2024-6": 635264,
  "2024-7": 643883,
  "2024-8": 652623,
  "2024-9": 661457,
};

/* The data above was generated using this bash script:
#!/bin/bash

declare -A firstBlockOfTheMonth

for HEIGHT in {0..666657}
do
  TIMESTAMP=$(curl -s -X POST http://node.suchwow.xyz:34568/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"getblock","params":{"height":'$HEIGHT'}}' | jq '.result.block_header.timestamp')
  YRMO=$(date +'%Y-%m' -d "@"$TIMESTAMP) # Like "2022-11"
  if [ "${firstBlockOfTheMonth[$YRMO]+abc}" ]; then # Check if key $YRMO has been set in array firstBlockOfTheMonth.
    continue # We've already seen a block in this month.
  else # This is the first block of the month.
    echo '"'$YRMO'": '$HEIGHT
    firstBlockOfTheMonth[$YRMO]=$HEIGHT # Like firstBlockOfTheMonth["2021-5"]=312769.
  fi
  sleep 0.1
done
*/

@Deprecated("Something else should be used")
int getMoneroHeightByDate({required DateTime date}) {
  final raw = '${date.year}-${date.month}';
  final lastHeight = moneroDates.values.last;
  int? startHeight;
  int? endHeight;
  int height = 0;

  try {
    if ((moneroDates[raw] == null) || (moneroDates[raw] == lastHeight)) {
      startHeight = moneroDates.values.toList()[moneroDates.length - 2];
      endHeight = moneroDates.values.toList()[moneroDates.length - 1];
      final heightPerDay = (endHeight - startHeight) / 31;
      final endDateRaw =
          moneroDates.keys.toList()[moneroDates.length - 1].split('-');
      final endYear = int.parse(endDateRaw[0]);
      final endMonth = int.parse(endDateRaw[1]);
      final endDate = DateTime(endYear, endMonth);
      final differenceInDays = date.difference(endDate).inDays;
      final daysHeight = (differenceInDays * heightPerDay).round();
      height = endHeight + daysHeight;
    } else {
      startHeight = moneroDates[raw];
      final index = moneroDates.values.toList().indexOf(startHeight!);
      endHeight = moneroDates.values.toList()[index + 1];
      final heightPerDay = ((endHeight - startHeight) / 31).round();
      final daysHeight = (date.day - 1) * heightPerDay;
      height = startHeight + daysHeight - heightPerDay;
    }
  } catch (e) {
    // print(e);
    rethrow;
  }

  return height;
}

@Deprecated("Something else should be used")
int getWowneroHeightByDate({required DateTime date}) {
  final raw = '${date.year}-${date.month}';
  final lastHeight = wowneroDates.values.last;
  int? startHeight;
  int? endHeight;
  int height = 0;

  try {
    if ((wowneroDates[raw] == null) || (wowneroDates[raw] == lastHeight)) {
      startHeight = wowneroDates.values.toList()[wowneroDates.length - 2];
      endHeight = wowneroDates.values.toList()[wowneroDates.length - 1];
      final heightPerDay = (endHeight - startHeight) / 31;
      final endDateRaw =
          wowneroDates.keys.toList()[wowneroDates.length - 1].split('-');
      final endYear = int.parse(endDateRaw[0]);
      final endMonth = int.parse(endDateRaw[1]);
      final endDate = DateTime(endYear, endMonth);
      final differenceInDays = date.difference(endDate).inDays;
      final daysHeight = (differenceInDays * heightPerDay).round();
      height = endHeight + daysHeight;
    } else {
      startHeight = wowneroDates[raw];
      final index = wowneroDates.values.toList().indexOf(startHeight!);
      endHeight = wowneroDates.values.toList()[index + 1];
      final heightPerDay = ((endHeight - startHeight) / 31).round();
      final daysHeight = (date.day - 1) * heightPerDay;
      height = startHeight + daysHeight - heightPerDay;
    }
  } catch (e) {
    // print(e);
    rethrow;
  }

  return height;
}
