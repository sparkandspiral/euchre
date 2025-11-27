class ImmutableHistory<T> extends Iterable<T> {
  final _HistoryNode<T>? _tail;
  final int _length;

  const ImmutableHistory._(this._tail, this._length);

  const ImmutableHistory.empty() : this._(null, 0);

  ImmutableHistory<T> push(T value) =>
      ImmutableHistory._(_HistoryNode(value, _tail), _length + 1);

  ImmutableHistory<T> pop() {
    if (_tail == null) {
      return this;
    }
    return ImmutableHistory._(_tail.previous, _length - 1);
  }

  T? get lastOrNull => _tail?.value;

  T? get firstOrNull {
    var node = _tail;
    while (node != null && node.previous != null) {
      node = node.previous;
    }
    return node?.value;
  }

  @override
  bool get isEmpty => _tail == null;

  @override
  bool get isNotEmpty => !isEmpty;

  @override
  int get length => _length;

  @override
  T get last {
    final node = _tail;
    if (node == null) {
      throw StateError('No elements');
    }
    return node.value;
  }

  @override
  T get first {
    final value = firstOrNull;
    if (value == null) {
      throw StateError('No elements');
    }
    return value;
  }

  @override
  Iterator<T> get iterator => _HistoryIterator(_tail);
}

class _HistoryNode<T> {
  final T value;
  final _HistoryNode<T>? previous;

  const _HistoryNode(this.value, this.previous);
}

class _HistoryIterator<T> implements Iterator<T> {
  final List<T> _values;
  int _index = -1;
  T? _current;

  _HistoryIterator(_HistoryNode<T>? tail) : _values = _collect(tail);

  static List<T> _collect<T>(_HistoryNode<T>? tail) {
    final reversed = <T>[];
    var node = tail;
    while (node != null) {
      reversed.add(node.value);
      node = node.previous;
    }
    return reversed.reversed.toList();
  }

  @override
  T get current {
    if (_current == null) {
      throw StateError('No current element');
    }
    return _current as T;
  }

  @override
  bool moveNext() {
    if (_index + 1 >= _values.length) {
      _current = null;
      return false;
    }
    _current = _values[++_index];
    return true;
  }
}
