/**
 * One record shared by every relationship that references it - the same instance
 * and Id everywhere, generated at most once per test method.
 *
 * ```apex
 * XFTY_SharedAncestor.put('acme-hq', new Account(Name = 'ACME HQ'));
 *
 * new XFTY_DummySObjectMasterTemplate(Contact.Id)
 *     .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('acme-hq'));
 * ```
 *
 * `put(name, ...)` registers and returns a {@link XFTY_SharedAncestorProvider} -
 * chain `.put(field, ...)` / `.putRequired(...)` / `.fromVariant(...)` /
 * `.copyingRelatedField(...)` to shape the shared record. `get(name)` only
 * retrieves the token to hand to `putRequired` / `putOptional`, and the handle
 * for `resolveNow` / `getId`.
 *
 * Flyweight - state is static and resets between test methods.
 * {@link XFTY_SharedAncestorResolver} resolves every registered ancestor before
 * the first `supply*()` call. `put(name, record)` disambiguates by Id - a record
 * **with** an Id is a fixed value, one **without** an Id an override template;
 * `putAsValue(...)` / `putAsTemplate(...)` choose explicitly.
 *
 * See docs/use/shared-ancestors.md.
 */
@IsTest
public class XFTY_SharedAncestor implements XFTY_SharedRelationshipIntf {

    private static final Map<String, XFTY_SharedAncestor> BY_NAME = new Map<String, XFTY_SharedAncestor>();
    private static final Set<String> DISABLED = new Set<String>();
    private static Boolean manualResolution = false;

    private final String name;
    private XFTY_SharedAncestorProvider source;
    private SObject resolvedRecord;
    private XFTY_DummySObjectBundle resolvedBundle;
    private Boolean resolvedRecordIsPersisted = false;

    private XFTY_SharedAncestor(String name) {
        this.name = name;
    }

    // Retrieval ---------------------------------------------------------

    /** The interned instance for `name` - the token for `putRequired(field, ...)`. Creates it on first use. */
    public static XFTY_SharedAncestor get(String name) {
        if (String.isBlank(name)) {
            throw new XFTY_DummySObjectFtyProviderException('A shared ancestor needs a non-blank name.');
        }
        if (!BY_NAME.containsKey(name)) {
            BY_NAME.put(name, new XFTY_SharedAncestor(name));
        }
        return BY_NAME.get(name);
    }

    public static Id getId(String name) {
        if (DISABLED.contains(name)) {
            throw new XFTY_DummySObjectFtyProviderException('Shared ancestor "' + name + '" is disabled.');
        }
        XFTY_SharedAncestor ancestor = get(name);
        if (ancestor.resolvedRecord == null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + name + '" is not resolved yet. Reference it in a supply*() call first, '
                            + 'or call XFTY_SharedAncestor.get("' + name + '").resolveNow(lookup, mode).'
            );
        }
        return ancestor.resolvedRecord.Id;
    }

    // Registration ----------------------------------------------------

    /**
     * Register `record`. Disambiguates by Id: a record **with** an Id becomes a
     * fixed value (as {@link #putAsValue}); one **without** an Id becomes an
     * override template (as {@link #putAsTemplate}). Logs the choice.
     */
    public static XFTY_SharedAncestorProvider put(String name, SObject record) {
        Boolean asFixedValue = record != null && record.Id != null;
        System.debug(LoggingLevel.INFO,
                'XFTY_SharedAncestor.put("' + name + '"): record '
                        + (asFixedValue
                                ? 'has an Id - registering it as a fixed value'
                                : 'has no Id - registering it as an override template')
                        + '. Call putAsValue(...) / putAsTemplate(...) to choose explicitly.');
        return asFixedValue ? putAsValue(name, record) : putAsTemplate(name, record);
    }

    /** Register an override template; the shared record is generated from it in the pre-phase. */
    public static XFTY_SharedAncestorProvider putAsTemplate(String name, SObject template) {
        return get(name).provider().withTemplate(template);
    }

    /** Register a record the test built itself; used as-is. WARNs if it replaces a different resolved one. */
    public static XFTY_SharedAncestorProvider putAsValue(String name, SObject record) {
        XFTY_SharedAncestor ancestor = get(name);
        if (ancestor.resolvedRecord != null && ancestor.resolvedRecord != record) {
            System.debug(LoggingLevel.WARN,
                    'XFTY_SharedAncestor.putAsValue("' + name + '"): replacing an already-resolved record.');
        }
        ancestor.resolvedRecord = record;
        ancestor.resolvedBundle = null;
        ancestor.resolvedRecordIsPersisted = (record != null && record.Id != null);
        return ancestor.provider();
    }

    /** Register just the Provider variant that generates the shared record. */
    public static XFTY_SharedAncestorProvider put(String name, XFTY_LookupKeyIntf variantKey) {
        return get(name).provider().fromVariant(variantKey);
    }

    /** `put(name, record)` (same Id-disambiguation), applied only if `name` is not registered yet. */
    public static XFTY_SharedAncestorProvider putIfAbsent(String name, SObject record) {
        XFTY_SharedAncestor ancestor = get(name);
        return ancestor.isUnregistered() ? put(name, record) : ancestor.provider();
    }

    /** As {@link #putIfAbsent(String, SObject)}, pinning the variant instead of a template. */
    public static XFTY_SharedAncestorProvider putIfAbsent(String name, XFTY_LookupKeyIntf variantKey) {
        XFTY_SharedAncestor ancestor = get(name);
        return ancestor.isUnregistered() ? put(name, variantKey) : ancestor.provider();
    }

    // Developer control over resolution -----------------------------

    /**
     * This shared ancestor is never resolved; any reference to it leaves the
     * child's foreign key **null**. For null-scenario tests, or dropping a heavy
     * default a test does not need. `getId(name)` on a disabled one throws.
     */
    public static void disable(String name) {
        get(name).assertUnresolved('disable(...)');
        DISABLED.add(name);
    }

    /**
     * Turn off the pre-phase that auto-resolves every registered shared ancestor.
     * A **lightweight** shared ancestor (no sub-graph of its own) still resolves
     * on-demand when first referenced; a **heavy** one throws unless it was
     * resolved up front with `resolveNow(...)`.
     */
    public static void manualResolutionOnly() {
        manualResolution = true;
    }

    /** Package-internal: is auto-resolution off this test method? */
    public static Boolean isManualResolutionOnly() {
        return manualResolution;
    }

    /** Resolve a named set of shared ancestors up front, in one depth-batched pass. */
    public static void resolveNow(
            XFTY_DummySObjectProviderLookupIntf lookup, XFTY_InsertModeEnum insertMode, List<String> names
    ) {
        XFTY_SharedAncestorResolver.applyLookupDefaults(lookup);
        List<XFTY_SharedAncestor> toResolve = new List<XFTY_SharedAncestor>();
        for (String name : names) {
            XFTY_SharedAncestor ancestor = get(name);
            if (ancestor.resolvedRecord == null) {
                toResolve.add(ancestor);
            }
        }
        if (!toResolve.isEmpty()) {
            new XFTY_SharedAncestorResolver(lookup, insertMode).resolve(toResolve);
        }
    }

    /** Package-internal, for {@link XFTY_SharedAncestorResolver}: every registered ancestor not yet resolved. */
    public static List<XFTY_SharedAncestor> configuredUnresolved() {
        List<XFTY_SharedAncestor> pending = new List<XFTY_SharedAncestor>();
        for (XFTY_SharedAncestor ancestor : BY_NAME.values()) {
            if (ancestor.source != null && ancestor.resolvedRecord == null && !DISABLED.contains(ancestor.name)) {
                pending.add(ancestor);
            }
        }
        return pending;
    }

    private Boolean isUnregistered() {
        return this.source == null && this.resolvedRecord == null;
    }

    private XFTY_SharedAncestorProvider provider() {
        if (this.source == null) {
            this.source = new XFTY_SharedAncestorProvider(this);
        }
        return this.source;
    }

    /** Called by {@link XFTY_SharedAncestorProvider} before each configuration change. */
    public void assertUnresolved(String call) {
        if (this.resolvedRecord != null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + this.name + '" is already resolved; ' + call + ' would have no effect.'
            );
        }
    }

    // Resolution ------------------------------------------------------

    /** Resolve now - e.g. to read `getId(name)` before any `supply*()` call. */
    public XFTY_SharedAncestor resolveNow(XFTY_DummySObjectProviderLookupIntf lookup, XFTY_InsertModeEnum insertMode) {
        if (this.resolvedRecord == null) {
            XFTY_SharedAncestorResolver.applyLookupDefaults(lookup);
            new XFTY_SharedAncestorResolver(lookup, insertMode).resolve(new List<XFTY_SharedAncestor>{ this });
        }
        return this;
    }

    /** Package-internal, for {@link XFTY_SharedAncestorResolver}: the recipe for this ancestor's record. */
    public XFTY_SharedAncestorProvider source() {
        if (this.source == null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + this.name + '" was never registered - call XFTY_SharedAncestor.put("'
                            + this.name + '", template / key).'
            );
        }
        return this.source;
    }

    /** Package-internal: the resolver hands back the generated record and its graph. */
    public void acceptResolved(SObject record, XFTY_DummySObjectBundle bundle, Boolean persisted) {
        this.resolvedRecord = record;
        this.resolvedBundle = bundle;
        this.resolvedRecordIsPersisted = persisted;
    }

    // XFTY_DummyDefaultRelationshipIntf --------------------------------

    public SObject getOverrideTemplate() {
        return (this.source == null) ? null : this.source.overrideTemplate();
    }

    public SObjectField getRelatedField() {
        return (this.source == null) ? null : this.source.relatedField();
    }

    public XFTY_LookupKeyIntf resolveLookupKey(XFTY_DummySObjectProviderLookupIntf providerLookup) {
        return this.source().lookupKey(providerLookup);
    }

    // XFTY_SharedRelationshipIntf -------------------------------------

    public String getSharedName() {
        return this.name;
    }

    public Boolean isResolved() {
        return this.resolvedRecord != null;
    }

    public Boolean isResolvedRecordPersisted() {
        return this.resolvedRecordIsPersisted;
    }

    public SObject resolveSharedRecord(XFTY_GenerationContext context) {
        if (DISABLED.contains(this.name)) {
            return null;   // the child's foreign key is left null on purpose
        }
        if (this.resolvedRecord != null) {
            return this.resolvedRecord;
        }
        if (manualResolution) {
            return this.resolveUnderManualMode(context);
        }
        XFTY_SharedAncestorResolver.resolveAllConfigured(context.providerLookup, context.insertMode);
        if (this.resolvedRecord == null) {
            // Registered after the pre-phase ran (a later supply*() call) - resolve it alone.
            this.resolveNow(context.providerLookup, context.insertMode);
        }
        return this.resolvedRecord;
    }

    private SObject resolveUnderManualMode(XFTY_GenerationContext context) {
        if (this.source().isLightweight(context.providerLookup)) {
            this.resolveNow(context.providerLookup, context.insertMode);
            return this.resolvedRecord;
        }
        throw new XFTY_DummySObjectFtyProviderException(
                'Shared ancestor "' + this.name + '" has a sub-graph of its own and auto-resolution is off '
                        + '(manualResolutionOnly). Resolve it up front: XFTY_SharedAncestor.get("' + this.name
                        + '").resolveNow(lookup, mode), or XFTY_SharedAncestor.resolveNow(lookup, mode, names).'
        );
    }

    /**
     * The shared record as a single-record sub-bundle, so `getBundle(field)` and
     * `getList(field)` stay consistent. For a `putAsValue(...)` record, one is
     * built on first request. Never null once resolved.
     */
    public XFTY_DummySObjectBundle getResolvedBundle() {
        if (this.resolvedBundle == null && this.resolvedRecord != null) {
            this.resolvedBundle = singleRecordBundle(this.resolvedRecord);
        }
        return this.resolvedBundle;
    }

    private static XFTY_DummySObjectBundle singleRecordBundle(SObject record) {
        SObjectField idField = record.getSObjectType().getDescribe().fields.getMap().get('Id');
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(idField, new List<SObject>{ record });
        return bundle;
    }
}
