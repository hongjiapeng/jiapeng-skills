# .NET Engineering Guidelines

Use this template when the target repository is a .NET project. Reference it from feature specs and implementation plans instead of repeating these common rules.

## Baseline Rule

Follow the existing architecture of the target repository. Do not force Clean Architecture, DDD, CQRS, MediatR, complex layering, or a new framework unless the project size and requirement justify the tradeoff. Prefer simple vertical slices for small tools. Keep architecture decisions explicit and reversible.

## Project Structure

- Keep new code in the nearest existing project, namespace, and folder pattern.
- Add new projects only when there is a clear deployment, testing, ownership, or reuse boundary.
- Keep UI, application logic, infrastructure, and persistence separated only to the degree the repository already supports or the requirement needs.
- Avoid broad folder reshuffles during feature work.

## ASP.NET Core Host Shape

- Treat `Microsoft.NET.Sdk.Web` and `Microsoft.NET.Sdk` plus `Microsoft.AspNetCore.App` as different host shapes with different defaults.
- If converting an ASP.NET Core host to a console-style executable using `Microsoft.NET.Sdk`, explicitly configure `OutputType`, static asset copy rules, content root, web root, and launch settings.
- Verify `GET /` and static assets from the built output, not only from the source tree.
- If the app should be HTTP-only for LAN or local development, add an explicit HTTP-only `launchSettings.json` profile so tooling does not regenerate HTTPS defaults or prompt for development certificate trust.
- Do not simulate browser chrome or OS window controls in a web app simply because a design mockup includes them; keep or remove them based on product intent and the real runtime context.

## Layering Rules

- Preserve existing dependencies between projects and layers.
- Keep domain or application logic independent from UI frameworks when the project already follows that pattern.
- Keep infrastructure details behind existing service abstractions when they exist.
- Do not introduce Clean Architecture, DDD, CQRS, or mediator layers by default.

## Dependency Injection and IoC Boundaries

- Prefer `Microsoft.Extensions.DependencyInjection` unless the target project already uses another container.
- Register services at the existing composition root.
- Keep IoC container usage at application boundaries; avoid resolving services from deep application code.
- Prefer constructor injection for required dependencies.
- Avoid service locator patterns unless the existing architecture already uses them and changing it is out of scope.

## Service Registration

- Match existing lifetimes and naming conventions.
- Use singleton only for stateless, thread-safe services or shared infrastructure objects designed for reuse.
- Use scoped when the host has a meaningful scope such as a web request.
- Use transient for lightweight stateless services.
- Keep registration extensions small and colocated with the owning project when the repository already uses extension methods.

## Configuration Management

- Use `IConfiguration` at the boundary and bind strongly typed settings where values are used repeatedly.
- Prefer environment-specific configuration files and environment variables over hardcoded values.
- Do not add secrets to source-controlled configuration.
- Keep defaults explicit and safe.

## Options Pattern

- Use the Options Pattern for cohesive settings groups.
- Prefer `IOptions<T>` for stable app-start settings, `IOptionsMonitor<T>` for reloadable or long-running service settings, and `IOptionsSnapshot<T>` only where scoped web-request behavior is useful.
- Validate options at startup when invalid configuration would make the feature fail later.

## Logging

- Prefer `Microsoft.Extensions.Logging` as the logging abstraction.
- Use structured log messages with stable property names when useful.
- Allow providers such as Serilog or NLog only when the target project already uses them or the requirement justifies structured logging.
- Do not log secrets, tokens, personal data, full file contents, or sensitive paths unless the project already has a safe redaction policy.

## Exception Handling

- Catch exceptions at boundaries where recovery, retry, translation, logging, or user-facing messages are possible.
- Do not swallow exceptions silently.
- Preserve stack traces when rethrowing.
- Convert expected failures into validation results, status codes, or user-facing states as appropriate for the app type.

## Validation

- Validate external input at the boundary: UI input, API requests, configuration, files, command-line args, network payloads, and persisted data.
- Keep validation messages actionable and safe.
- Do not rely only on UI validation when backend or service code can be called directly.

## Async, Await, and Cancellation

- Use `async`/`await` for IO-bound work.
- Avoid blocking async work with `.Result`, `.Wait()`, or sync-over-async patterns.
- Pass `CancellationToken` through public async methods and long-running operations.
- Honor cancellation in loops, network calls, file IO, and background work where practical.
- Use `ConfigureAwait(false)` only where it matches the repository's established style and context requirements.

## Background Tasks

- Use the host's existing background task pattern.
- For worker services, prefer `BackgroundService` or existing hosted-service patterns.
- Keep background loops cancellable and observable.
- Add backoff, retry limits, and failure logging for repeated operations.
- Do not update UI state directly from background threads.

## File and Network IO

- Validate paths and handle missing files, permissions, locked files, partial writes, and cleanup.
- Use async IO for potentially slow operations.
- Prefer atomic writes when corrupt partial files would matter.
- Add timeouts, cancellation, and bounded retries for network calls.
- Avoid assuming network availability.

## HttpClientFactory

- Use `IHttpClientFactory` when the app already uses it, when creating repeated outbound HTTP clients, or when resilience and configuration are needed.
- Prefer named or typed clients for external services.
- Configure base addresses, headers, timeouts, and handlers in the composition root.
- Do not create a new `HttpClient` per request in long-running applications.

## Data Persistence Boundaries

- Keep persistence code behind existing repositories, data services, DbContexts, or storage abstractions.
- Do not change schemas, migrations, or file formats without calling it out in the spec and rollback plan.
- Preserve backward compatibility unless the requirement explicitly allows a breaking change.
- Keep transaction boundaries explicit for multi-step writes.

## Unit and Integration Testing

- Add unit tests for pure logic, validation, mapping, and edge cases.
- Add integration tests for API contracts, persistence, filesystem behavior, background services, and dependency registration when relevant.
- Prefer testing through existing public seams rather than exposing internals only for tests.
- Include manual verification for UI, installer, service, or OS integration behavior.
- Avoid running build and test commands concurrently against the same output folders unless the repository is designed for it; .NET builds and test runs can lock assemblies and produce false failures.

## Build and Packaging

- Keep target frameworks aligned with the repository.
- Do not change SDK versions, RuntimeIdentifiers, trimming, single-file, AOT, signing, installer, NuGet, MSIX, winget, or CI behavior unless in scope.
- For packaging changes, include install, upgrade, uninstall, rollback, and signing considerations.
- Keep generated artifacts out of source control unless the repository already tracks them.
- Before rebuilding, check whether the app executable is running and locking files under `bin`. Stop only processes that are clearly in scope, or report the lock and exact PID.

## NuGet Dependencies

- Prefer existing dependencies and the .NET base class libraries.
- Add a package only when it solves a clear problem and the tradeoff is documented.
- Check license, maintenance, transitive dependencies, target framework support, and package size.
- Avoid introducing framework-scale packages for small vertical slices.

## Security and Secrets

- Do not commit secrets, tokens, keys, certificates, connection strings, or private endpoints.
- Use user secrets, environment variables, secure stores, or existing project secret management.
- Redact sensitive values in logs and errors.
- Validate and normalize external input before using it in file paths, shell commands, URLs, SQL, or serialization.
- Preserve existing authentication and authorization boundaries unless the requirement explicitly changes them.
