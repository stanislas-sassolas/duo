/// Résultat typé d'une opération pouvant échouer, sans exception à propager
/// jusqu'à l'UI. Simple et suffisant pour le MVP.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;

  /// Valeur si succès, sinon `null`.
  T? get valueOrNull => this is Success<T> ? (this as Success<T>).value : null;

  R when<R>({
    required R Function(T value) success,
    required R Function(String message) failure,
  }) {
    final self = this;
    if (self is Success<T>) return success(self.value);
    return failure((self as Failure<T>).message);
  }
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

class Failure<T> extends Result<T> {
  const Failure(this.message, {this.cause, this.permanent = false});
  final String message;
  final Object? cause;

  /// `true` si réessayer ne servira à rien (refus des règles, donnée
  /// invalide…), par opposition à une erreur passagère (réseau).
  final bool permanent;
}
