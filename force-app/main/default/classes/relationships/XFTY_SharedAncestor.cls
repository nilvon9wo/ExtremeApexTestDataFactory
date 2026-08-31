/**
 * One record, shared by every relationship that references it - the same
 * instance and the same Id everywhere, generated at most once per test method.
 *
 * ```apex
 * // configure once, centrally
 * XFTY_SharedAncestor.get('acme-hq').of(new Account(Name = 'ACME HQ'));
 *
 * // reference it from any Master Template, any field
 * new XFTY_DummySObjectMasterTemplate(Contact.Id)
 *     .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('acme-hq'))
 *
 * new XFTY_DummySObjectMasterTemplate(Case.Id)
 *     .putOptional(Case.AccountId, XFTY_SharedAncestor.get('acme-hq'))
 * ```
 *
 * Generate 50 Contacts under one `acme-hq` Account with a single generated
 * Account and (in `NOW` mode) a single Account insert.
 *
 * Flyweight: obtain instances with `get(name)`, never `new`. State is static, so
 * it resets between test methods automatically - each method starts clean and is
 * responsible for its own shared ancestors (Salesforce never shares data between
 * tests). No reset hook is needed or provided.
 *
 * **One API, resolution handled automatically.** There is nothing to declare or
 * register - configure a shared ancestor with `get(name).of(...)` and reference
 * it. Before a Provider generates anything, every shared ancestor configured
 * this test method is resolved in one place ({@link #ensureConfiguredAncestorsResolved}):
 *
 * - a **flat** one (its Provider has no relationships of its own) becomes a
 *   single record;
 * - a **deep** one (its Provider pulls in ancestors) has its whole sub-graph
 *   built once and persisted one dependency layer at a time - the fewest
 *   `insert` statements. A deep chain converging on a singleton root collapses
 *   to one shared sub-graph.
 *
 * Either way the caller's insert mode is honoured (`NOW` inserts, `MOCK`
 * mock-Ids, `NEVER` leaves it in memory; a `DEFERRED` / `.depthBatched()` call
 * resolves its shared ancestors up front so they are ready when the deferred
 * graph flushes).
 *
 * **How much you can say about the shared record.** `of(template)` and/or
 * `withKey(variant)` cover the simple case. For anything richer - value
 * strategies, `putRequired` / `includeOptional` / `put(path, ...)` into its own
 * ancestors, child collections - hand `suppliedBy(...)` a fully-configured
 * `XFTY_DummySObjectProvider`; the whole generation API then describes the one
 * shared record.
 *
 * A shared ancestor that references itself while resolving - directly or round a
 * chain of other shared ancestors - is a cycle: it throws, and the fix is to
 * register one side with `put(name, record)`.
 *
 * See docs/use/shared-ancestors.md.
 */
@IsTest
public class XFTY_SharedAncestor implements XFTY_SharedRelationshipIntf {

    private static final Map<String, XFTY_SharedAncestor> BY_NAME = new Map<String, XFTY_SharedAncestor>();

    private final String name;
    private XFTY_SharedAncestorProvider source;
    private XFTY_KeyedAncestorProvider keyedSource;   // set iff `source` is the keyed kind
    private SObjectField relatedField;
    private SObject resolvedRecord;
    private XFTY_DummySObjectBundle resolvedBundle;
    private Boolean resolvedRecordIsPersisted = false;

    private XFTY_SharedAncestor(String name) {
        this.name = name;
    }

    /** The interned instance for `name`, creating it on first use. */
    public static XFTY_SharedAncestor get(String name) {
        if (String.isBlank(name)) {
            throw new XFTY_DummySObjectFtyProviderException('A shared ancestor needs a non-blank name.');
        }
        if (!BY_NAME.containsKey(name)) {
            BY_NAME.put(name, new XFTY_SharedAncestor(name));
        }
        return BY_NAME.get(name);
    }

    /**
     * `get(name)`, configuring it with `template` only if it has not been
     * configured yet this test method (later calls ignore `template`). Lets a
     * shared setup helper that may run more than once - or that configures more
     * ancestors than one test uses - carry its own defaults inline.
     */
    public static XFTY_SharedAncestor getOrElse(String name, SObject template) {
        XFTY_SharedAncestor ancestor = get(name);
        if (ancestor.isUnconfigured()) {
            ancestor.of(template);
        }
        return ancestor;
    }

    /** As {@link #getOrElse(String, SObject)}, but pins the Provider variant instead of a template. */
    public static XFTY_SharedAncestor getOrElse(String name, XFTY_LookupKeyIntf variantKey) {
        XFTY_SharedAncestor ancestor = get(name);
        if (ancestor.isUnconfigured()) {
            ancestor.withKey(variantKey);
        }
        return ancestor;
    }

    private Boolean isUnconfigured() {
        return this.source == null && this.resolvedRecord == null;
    }

    private Boolean isConfigured() {
        return this.source != null;
    }

    /** Package-internal, for {@link XFTY_SharedAncestorResolver}: the recipe for this ancestor's record. */
    public XFTY_SharedAncestorProvider source() {
        if (this.source == null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + this.name + '" was never configured. Call '
                            + 'XFTY_SharedAncestor.get("' + this.name + '").of(...), .withKey(...), or .suppliedBy(...).'
            );
        }
        return this.source;
    }

    // Automatic pre-phase --------------------------------------------------
    //
    // Called by the Provider before it generates anything. Every shared ancestor
    // configured this test method is resolved now, each in one depth-batched
    // pass over its own sub-graph, honouring the caller's insert mode. Idempotent
    // - a resolved ancestor is skipped, so repeated supply*() calls cost only the
    // BY_NAME scan. Re-entrant calls (a shared ancestor's own generation reaching
    // another one inline) are a no-op here - the inner reference resolves itself.

    private static Boolean prePhaseRunning = false;
    private static final Set<String> IN_PROGRESS = new Set<String>();

    /** Resolve every configured shared ancestor, before the main graph build. */
    public static void ensureConfiguredAncestorsResolved(
            XFTY_DummySObjectProviderLookupIntf providerLookup,
            XFTY_InsertModeEnum callInsertMode
    ) {
        if (prePhaseRunning) {
            return;
        }
        List<XFTY_SharedAncestor> pending = new List<XFTY_SharedAncestor>();
        for (XFTY_SharedAncestor ancestor : BY_NAME.values()) {
            if (!ancestor.isResolved() && ancestor.isConfigured()) {
                pending.add(ancestor);
            }
        }
        if (!pending.isEmpty()) {
            new XFTY_SharedAncestorResolver(providerLookup, resolutionModeFor(callInsertMode)).resolve(pending);
        }
    }

    /**
     * Package-internal, for {@link XFTY_SharedAncestorResolver}: mark the whole
     * pre-phase as running so a nested `supplyBundle()` (a shared ancestor built by
     * its own configured Provider) does not start a second scan of the registry.
     * `enterPrePhase()` returns `false` when it was already running (a re-entrant
     * caller must not clear the flag).
     */
    public static Boolean enterPrePhase() {
        if (prePhaseRunning) {
            return false;
        }
        prePhaseRunning = true;
        return true;
    }
    public static void exitPrePhase() {
        prePhaseRunning = false;
    }

    /**
     * Package-internal, for {@link XFTY_SharedAncestorResolver}: mark this ancestor
     * as mid-resolution (returns `false` if it already is - a re-entrant hit), and
     * report whether a named ancestor is mid-resolution (a live cycle).
     */
    public Boolean beginResolving() {
        if (IN_PROGRESS.contains(this.name)) {
            return false;
        }
        IN_PROGRESS.add(this.name);
        return true;
    }
    public void endResolving() {
        IN_PROGRESS.remove(this.name);
    }
    public static Boolean isResolving(String name) {
        return IN_PROGRESS.contains(name);
    }

    /**
     * Resolve this shared ancestor now, outside any `supply*()` call - for a test
     * that reads `getId(name)` before it generates anything.
     */
    public XFTY_SharedAncestor resolveNow(
            XFTY_DummySObjectProviderLookupIntf providerLookup,
            XFTY_InsertModeEnum insertMode
    ) {
        if (this.resolvedRecord == null) {
            new XFTY_SharedAncestorResolver(providerLookup, insertMode)
                    .resolve(new List<XFTY_SharedAncestor>{ this });
        }
        return this;
    }

    private static XFTY_InsertModeEnum resolutionModeFor(XFTY_InsertModeEnum callInsertMode) {
        Boolean resolveEagerly = callInsertMode == null
                || callInsertMode == XFTY_InsertModeEnum.DEFERRED
                || callInsertMode == XFTY_InsertModeEnum.RELATED_ONLY;
        return resolveEagerly ? XFTY_InsertModeEnum.NOW : callInsertMode;
    }

    public Boolean isResolved() {
        return this.resolvedRecord != null;
    }

    /** Package-internal: the resolver hands back the generated record + its bundle. */
    public void acceptResolved(SObject record, XFTY_DummySObjectBundle bundle, Boolean persisted) {
        this.resolvedRecord = record;
        this.resolvedBundle = bundle;
        this.resolvedRecordIsPersisted = persisted;
    }

    /**
     * Register a record the test built itself as this shared ancestor - from here
     * `get(name)` resolves to it and no record is generated. Logs a WARN if it
     * replaces a different, already-resolved record.
     */
    public static void put(String name, SObject record) {
        XFTY_SharedAncestor ancestor = get(name);
        if (ancestor.resolvedRecord != null && ancestor.resolvedRecord != record) {
            System.debug(LoggingLevel.WARN,
                    'XFTY_SharedAncestor.put("' + name + '"): replacing an already-resolved record.');
        }
        ancestor.resolvedRecord = record;
        ancestor.resolvedBundle = null;
        // A record handed in with an Id is treated as already inserted.
        ancestor.resolvedRecordIsPersisted = (record != null && record.Id != null);
    }

    /** The resolved record's Id. Throws if it has not been resolved yet this test method. */
    public static Id getId(String name) {
        XFTY_SharedAncestor ancestor = get(name);
        if (ancestor.resolvedRecord == null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + name + '" is not resolved yet. Reference it from a relationship in a '
                            + 'supply*() call first, register a record with XFTY_SharedAncestor.put("' + name
                            + '", record), or call XFTY_SharedAncestor.get("' + name + '").resolveNow(lookup, mode).'
            );
        }
        return ancestor.resolvedRecord.Id;
    }

    // Configuration ----------------------------------------------------------
    //
    // of(template) and/or withKey(variant) build a XFTY_KeyedAncestorProvider;
    // suppliedBy(provider) builds a XFTY_ConfiguredAncestorProvider. The two are
    // mutually exclusive - the Provider already says what of / withKey would.
    // copyingRelatedField composes with either.

    /** The override template for the shared record; also identifies its SObject type. */
    public XFTY_SharedAncestor of(SObject overrideTemplate) {
        this.assertUnresolved('of(...)');
        this.keyed('of(...)').withTemplate(overrideTemplate);
        return this;
    }

    /** Pin the Provider variant that generates the shared record. */
    public XFTY_SharedAncestor withKey(XFTY_LookupKeyIntf lookupKey) {
        this.assertUnresolved('withKey(...)');
        this.keyed('withKey(...)').withKey(lookupKey);
        return this;
    }

    /**
     * Build the shared record from a fully-configured `XFTY_DummySObjectProvider` -
     * anything a normal generation call can express (value strategies, `putRequired`
     * / `includeOptional` / `put(path, ...)`, a pinned variant). The Provider
     * carries its own override template and lookup, so `of(...)` / `withKey(...)`
     * are not used alongside it. The caller's insert mode still governs persistence.
     */
    public XFTY_SharedAncestor suppliedBy(XFTY_DummySObjectProvider provider) {
        this.assertUnresolved('suppliedBy(...)');
        if (this.source != null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + this.name + '": use suppliedBy(provider) OR of(...)/withKey(...), not both. '
                            + 'The Provider already carries its override template and variant.'
            );
        }
        this.source = new XFTY_ConfiguredAncestorProvider(provider);
        return this;
    }

    /** Copy this field from the shared record into the child's lookup, instead of its Id. */
    public XFTY_SharedAncestor copyingRelatedField(SObjectField relatedField) {
        this.assertUnresolved('copyingRelatedField(...)');
        this.relatedField = relatedField;
        return this;
    }

    /** The keyed recipe, created on first `of`/`withKey`; throws if `suppliedBy` already claimed the slot. */
    private XFTY_KeyedAncestorProvider keyed(String call) {
        if (this.source == null) {
            this.keyedSource = new XFTY_KeyedAncestorProvider(this.name);
            this.source = this.keyedSource;
        }
        if (this.keyedSource == null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + this.name + '": ' + call + ' cannot be combined with '
                            + 'suppliedBy(provider) - configure the Provider instead.'
            );
        }
        return this.keyedSource;
    }

    private void assertUnresolved(String call) {
        if (this.resolvedRecord != null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + this.name + '" is already resolved; ' + call + ' would have no effect.'
            );
        }
    }

    // XFTY_DummyDefaultRelationshipIntf ------------------------------------

    public SObject getOverrideTemplate() {
        return (this.keyedSource != null) ? this.keyedSource.overrideTemplate() : null;
    }

    public SObjectField getRelatedField() {
        return this.relatedField;
    }

    public XFTY_LookupKeyIntf resolveLookupKey(XFTY_DummySObjectProviderLookupIntf providerLookup) {
        return this.source().lookupKey(providerLookup);
    }

    // XFTY_SharedRelationshipIntf ----------------------------------------

    public String getSharedName() {
        return this.name;
    }

    public SObject resolveSharedRecord(XFTY_GenerationContext context) {
        if (this.resolvedRecord != null) {
            return this.resolvedRecord;
        }
        // Normally the Provider's pre-phase has already resolved every configured
        // shared ancestor. Reaching an unresolved one here means it was configured
        // after that pre-phase ran (a later supply*() call in the same test) -
        // resolve it now, alone, in the same depth-batched way.
        XFTY_SharedAncestor.ensureConfiguredAncestorsResolved(context.providerLookup, context.insertMode);
        if (this.resolvedRecord == null) {
            this.resolveNow(context.providerLookup, resolutionModeFor(context.insertMode));
        }
        return this.resolvedRecord;
    }

    /**
     * A bundle exposing the shared record as a single-record sub-graph. It is the
     * bundle produced when the record was generated; for a record supplied with
     * `put(name, record)` there is no such bundle, so one wrapping just that
     * record is built on first request, keyed by its `Id` field. Never null once
     * the shared ancestor is resolved - `bundle.getBundle(field)` and
     * `bundle.getList(field)` stay consistent.
     */
    public XFTY_DummySObjectBundle getResolvedBundle() {
        if (this.resolvedBundle == null && this.resolvedRecord != null) {
            this.resolvedBundle = wrap(this.resolvedRecord);
        }
        return this.resolvedBundle;
    }

    private static XFTY_DummySObjectBundle wrap(SObject record) {
        SObjectField idField = record.getSObjectType()
                .getDescribe()
                .fields
                .getMap()
                .get('Id');
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(idField, new List<SObject>{ record });
        return bundle;
    }

    /**
     * Whether the shared record has been inserted (has a real Id). A child being
     * generated with `NOW` needs this to be true, or its lookup would carry a
     * mock / null Id into a real `insert`.
     */
    public Boolean isResolvedRecordPersisted() {
        return this.resolvedRecordIsPersisted;
    }
}
