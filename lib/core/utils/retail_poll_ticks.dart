/// Trigger an immediate retail projection read, then refresh while subscribed.
Stream<int> retailPollTicks(Duration interval) async* {
  yield 0;
  yield* Stream<int>.periodic(interval, (tick) => tick + 1);
}
