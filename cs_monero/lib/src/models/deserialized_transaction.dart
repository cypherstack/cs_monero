import '../utils/byte_reader.dart';
import 'tx_extra.dart';
import 'tx_input.dart';
import 'tx_output.dart';

/// Represents a Monero transaction as deserialized from a hex string.
///
/// Distinct from the Transaction class used elsewhere in the codebase, this
/// can only contain that information which can be deserialized from a
/// transaction in hex as would be returned from a node's JSON-RPC API.
///
/// Example:
/// ```dart
/// import 'package:cs_monero/src/models/deserialized_transaction.dart';
/// import 'package:cs_monero/src/models/tx_extra.dart';
/// import 'package:cs_monero/src/models/tx_input.dart';
/// import 'package:cs_monero/src/models/tx_output.dart';
///
/// void main() {
///   final hexTransaction =
///       '02000202001082bedc2cacaed10881dc62afe59201d18931f4ffc501c0b90eabe202eba611bcf002f5f202c3ba02aaad02cd17d7e802fb06bbe60f26734f9d37abbc262cfa6013a82e3a99360e82c66285c99bebd0bfdb500200108cecc21ce6f1f111f7b9f00899da608edba10199a008d6c80adaac01efe805df3de9ce01efd402bd619edb03dd13d7027bb542d92e3e2e820aed8b95cad83b1cb76023e22d1720c2f8c4428d82fe3011040003c001ac2490c11c15a878f3502bf2173a4a7246f6fdf583476c08bba67cc3c2f6790003ddc101b6f11ba9bec48c9b726249d5e24e8007cd65e180c0e3ace99ba810cb383a0003edc933be5a907f216b5ebf82adcde4d148d108c3db32c32ffe5f04e6d6ec9076fd0003e05e5869ddd5a17e33446ee80127f39a0082c6711998d81093d9fbe3f1775a47f9a30101e16fe189b4f9c244e8ff97ff92c6ba177e124f356d589515371cab5314c870ee04048eef974eaa872f2aaf3ee1d578cf91a087282f1245fe2147af0611ac44ebd2d7129e05dfead3f5fbaedbe4ccf969244d6ec8b3e4cd1025f223684d8fd983357b76d685d9f31c2558d7cab941141244eaa101ddf87c6c57f2e3a232d9114425d51372e4e797ac4517ab7bb7f71512880f0605a6cd7f58f7f7fe5b53650cb57b480680c8ddcd03995c352c9ed234717958283b39b0b2a7e358d0c4322cbcf4fa2c68a5a4622455d1abc3cae9c8c8664e1238fbe8b31520c39e3247dcffcbc1102928521d3adaf2b7056273fe856b6fa0c854c3539e30588b44580cbf09e32f165c3c2df6c4e09b0da792ca214643ff8f188a467ef9805297718027bdb952a819eb3d5440d042bbfe15141d6be7b558cbd9da684aa84268e09ab0e2949d3e486c4e663cf1cbd3b3011f65b2db108bb00d3c0a6810f38398e75060c8533c7a21954051ab2a72583b2cbfb6acba899c6c2649bcac3e3411f089a729e7d40df5a4dd743a492f74d9a1c1615d0b649f14dae3b6e95bbb5631c1c88a82a3ce6bfb2dbe1545e16045d9a79f8da20b9f5e9b3b9b873175faa5ebd8afe2ac63a527a56fe0c95cadf1f954840efcea07762dc8cdd9928d7da4ed8ac90f0eb35b62b982a641b10f5ab21dca1c0037180874a94516114794decbacb2af3b48fea510e79b2726895aef0129d6cc0c083b4e32cc95e9a294a069780cabfb40dc24802eb00b270960cb7d41fd017d3df173400852984cc2111dec0a7df4939513e4c7d8414c16aaa760a284988dc4b847bdba4978d2b2a81047ebd7d2ca88cd59b372fa33abd0c12c42ed853ca940438914d12c336d6c4df522930439dbe6a67bdec780b310447e3572078638aa471452770ec8c4e98fb147d874e7f795365ab1d8f41be9a3be7ff00afbcd2afd6caf0267741140da68a3c8f7b4fa56ca19c75d920fc68afab037d6f9fe7660c62402a68c8558989bc9a60c21c4b6564e22069dc42d0a43e4565e706c31ab8ee391b224728a015de30ad5bfba818b1a0497623dfcb13e496e6ee513d4e59f9f9ca621f7081b600d034e552a2d7321fe3aeaa0970cb70768973c7de8fd8efab1648562f5398581c940990228d2878b1d6712993f450cc96554a2ab45b434f51b1b76d057c108e6bbd33de32e8a5abd0db1663d72cc5e72e6c3712b8e2c4d0fff09934cf750865cfe08ca11c3c792d25b3609735ef4fdba396456055f37cd8bdb3133affbb4603c8a97da7a71f2e2ed8932784013dcc2dd53d3dd5b9d7a31a0ddd7c730d78fed7ee522aed468f2370c55b9cba208046d1095cccebc0436f998a910680555c419fb3a92b4a98af5ad9a22ec89b82eee88ef53c377a6a6fc767a5bc1e33654b462c2229037c2e457ad7dea9041151f4c6b1a6cafbcf8df95b2a9547c12912e8a62e55e847e16d300e490a335cc631fec3e430a7bfde1cfbfb1fa3c0ed9972a0238cc7586c2bf76f63810aae78a68f74aba1cc6b17306bcdc6b81daa43793e60e59d1f5ed4fe7c47ee2a4f8a58188197fb520b6cd45a1d23f8bffd34bc52be00132b53e9638086ca53f9091c922e806eee064e6020404328965f6f7b7ee1c31014a4f5239eea5d7e32671314fc90d95d0b219287a1ece5ec0dad36d1eea26f90452d92eac57805666bc2cbe501448f98eed144ac47ff5aa562aabbc7a2580970b07d8ce2dd46c5aab610511257bff55b4a519d8e9a4255426e2250952c21ce908cc66ff0df763f3ed6b8fc263b9f902b8ad20815e1b308f999e38d04333a89501e0641289073a9068d176ceb34393873e1e81c2e8080a493f0ce40a972432120f0d7741e073a84b92133d8f44f91896ba0fd3cc33a748d6aea0e75174a3bdf302ef5dcf664953c2afd1381933261c698ce38725c49f8b5b646d091b71a7cfa90a55f904163b3b2e1909a2846c8392211a07a18b2000c36d7a4f0763daefc9330fea8f6999a888356ec92ae580effe3c7cd4f1bcf5d6786adc0ee6baf0aee131022eeb4e48164b8f179391e5870e754292786c245874c1f95b1f571e8df9714d04fde1d2d6e636260df2db0dc5445fad414a68c252d20c4ac0aa93bc77cab11d0032d46401d2d657f9f9fd3c4c137a1f38119eb63f6c8f5a9a73f865ddf41f230d08b971fd9782daad35a35a5f93ccfcef7de17a6e1f102ee2be968296b2cad90e1fdb02422be43738dfe8785d63eae3b0b834748a018abdff8b1e6718bd3db845fbed0eed84b84970d98e80e477ebe53782ed45c5487de289c0b61c181138900342d232f26f63865101c302e6ceb6479f7b0efaa60b03b00d9c00bb88ca6f3b039605f0fcd40bed038415e6d20dd507f2f37baa43c920d0e77eee9480a931c208206883e1defd6b646c024e8c95a4c485ecdbfc3d386f063b3eae427cd60fbb08523c2c76a96f0541ae3aec655f0c58948763b378d2040d5206193d950bc5a70588bf394e2f1991a225d4eec86f4b56285d05b3661d783b419a315f90261ac402cf492f788a5795d494ce3f460ea0a0f2dc24d062ea9a91d539882acb7f423e05d98d9785546d093e7afa3cb5e4b83b7c3f12e7b22ba4cb6694427b991118ea0a380477b20cfafea6b20096fd5a80dba7223931ffdb8708f35173ece08bf7bf0050ef943bca18a4219f503e4bf9bf215e606bf9d354314647d800326fa7ccb404f4cb412de34606b315e077b73b18ff9787db99156690d89d479d3050f23fae0284f0e2f093008b710f7bd8d176398b5ca29106a69db56f796c067da05af2b70bc30563f3c175ed88d3f2549ba6875245e85b1625ca9a7dd260deae06016bdc07572cc3e7db8ab971407388540f2d21c5d2a52e22009b469be5b75ef83d7d20027163eb85b0086f494ee4368e99616f3cbf3339ee16390c603556d02b9433ba0d78b8ef957e1b174db467cad6467542c22e2139e95be3979f05c7b8f8da8ca5080e9091949caf86df70e4d49a7740ba96ba1343e63a8b4e41602c421a1d53c90d32bb62ddf93a7631a8207f1bbfac44768a6bb8b7e499017cc23f961c4423b10ff5a756e91ec8faa4de8064132ae49afaaa83a81bb59db53412b8ff686eff315d07f68ece205f02be39b4e090c40bd7617dd4b0387b42a28ff6eaf22cac91d982'; // txid: bb2bc1506c3793f4dce9eea951546f6e7388b21764beebe69ae9590d65a66649.
///   final deserializedTx = DeserializedTransaction.deserialize(hexTransaction);
///
///   for (var input in deserializedTx.vin) {
///     if (input is TxinToKey) {
///       print('Key Image: ${_bytesToHex(input.keyImage)}');
///       print('Key Offsets: ${input.keyOffsets}');
///     }
///   }
///
///   for (var output in deserializedTx.vout) {
///     if (output.target is TxoutToKey) {
///       final txoutToKey = output.target as TxoutToKey;
///       print('Output Public Key: ${_bytesToHex(txoutToKey.key)}');
///     }
///   }
///
///   for (final field in deserializedTx.extraFields) {
///     if (field is TxExtraPubKey) {
///       print('Transaction Public Key: ${_bytesToHex(field.pubKey)}');
///     }
///   }
/// }
///
/// String _bytesToHex(List<int> bytes) {
///   return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
/// }
/// ```
class DeserializedTransaction {
  final BigInt version;
  final BigInt unlockTime;
  final List<TxInput> vin;
  final List<TxOutput> vout;
  final List<int> extra;
  final List<TxExtraField> extraFields;

  DeserializedTransaction({
    required this.version,
    required this.unlockTime,
    required this.vin,
    required this.vout,
    required this.extra,
    required this.extraFields,
  });

  factory DeserializedTransaction.deserialize(String hexTransaction) {
    final bytes = _hexToBytes(hexTransaction);
    final reader = ByteReader(bytes);

    final version = reader.readVarInt();
    final unlockTime = reader.readVarInt();

    final vinCount = reader.readVarInt().toInt();
    final vin = <TxInput>[];
    for (var i = 0; i < vinCount; i++) {
      vin.add(TxInput.fromReader(reader));
    }

    final voutCount = reader.readVarInt().toInt();
    final vout = <TxOutput>[];
    for (var i = 0; i < voutCount; i++) {
      vout.add(TxOutput.fromReader(reader));
    }

    // Read extra field.
    final extraSize = reader.readVarInt().toInt();
    final extra = reader.readBytes(extraSize);

    // Parse extra field.
    final extraFields = parseExtraField(extra);

    return DeserializedTransaction(
      version: version,
      unlockTime: unlockTime,
      vin: vin,
      vout: vout,
      extra: extra,
      extraFields: extraFields,
    );
  }
}

List<int> _hexToBytes(String hex) {
  final result = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    final byte = int.parse(hex.substring(i, i + 2), radix: 16);
    result.add(byte);
  }
  return result;
}
