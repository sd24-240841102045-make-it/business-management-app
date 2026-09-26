// ─────────────────────────────────────────────
// Enterprise Result & Failure Architecture
// ─────────────────────────────────────────────

abstract class Failure {
  final String message;
  final String? code;
  final dynamic details;

  const Failure(this.message, {this.code, this.details});

  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code, super.details});
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code, super.details});
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.code, super.details});
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code, super.details});
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code, super.details});
}

class Result<T> {
  final T? data;
  final Failure? failure;
  final bool isSuccess;

  const Result.success(T this.data)
      : failure = null,
        isSuccess = true;

  const Result.failure(Failure this.failure)
      : data = null,
        isSuccess = false;

  bool get isFailure => !isSuccess;

  R fold<R>(R Function(Failure failure) onFailure, R Function(T data) onSuccess) {
    if (isSuccess) {
      return onSuccess(data as T);
    } else {
      return onFailure(failure!);
    }
  }

  T getOrElse(T Function() defaultValue) {
    return isSuccess ? (data as T) : defaultValue();
  }

  Result<R> map<R>(R Function(T data) transform) {
    if (isSuccess) {
      return Result.success(transform(data as T));
    } else {
      return Result.failure(failure!);
    }
  }
}
