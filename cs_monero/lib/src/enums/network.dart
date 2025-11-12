enum Network {
  mainnet(0),
  testnet(1),
  stagenet(2);

  final int value;
  const Network(this.value);
}
