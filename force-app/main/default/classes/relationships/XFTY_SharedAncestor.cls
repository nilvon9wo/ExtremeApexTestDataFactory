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
 * `put(name, ...)` registers; `get(name)` only retrieves (the relationship token
 * for `putRequired`, and the handle for `resolveNow` / `getId`). Flyweight -
 * state is static and resets between test methods.
 * {@link XFTY_SharedAncestorResolver} resolves every registered ancestor before
 * the first `supply*()` call.
 *
 * `put(name, record)` disambiguates by Id - a record **with** an Id is registered
 * as a fixed value, one **without** an Id as an override template to generate
 * from. It logs which it chose; call `putAsValue(...)` / `putAsTemplate(...)` to
 * choose explicitly.
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
    //
    // putAsTemplate / put(name, key) build a XFTY_KeyedAncestorProvider;
    // put(name, provider) builds a XFTY_ConfiguredAncestorProvider; putAsValue
    // registers a record directly. copyingRelatedField composes with any of them.

    /**
     * Register `record`. Disambiguates by Id: a record **with** an Id becomes a
     * fixed value (as {@link #putAsValue}); one **without** an Id becomes an
     * override template (as {@link #putAsTemplate}). Logs the choice.
     */
    public static XFTY_SharedAncestor put(String name, SObject record) {
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
    public static XFTY_SharedAncestor putAsTemplate(String name, SObject template) {
        XFTY_SharedAncestor ancestor = get(name);
        ancestor.assertUnresolved('putAsTemplate(...)');
        ancestor.keyed('putAsTemplate(...)').withTemplate(template);
        return ancestor;
    }

    /** Register a record the test built itself; used as-is. WARNs if it replaces a different resolved one. */
    public static XFTY_SharedAncestor putAsValue(String name, SObject record) {
        XFTY_SharedAncestor ancestor = get(name);
        if (ancestor.resolvedRecord != null && ancestor.resolvedRecord != record) {
            System.debug(LoggingLevel.WARN,
                    'XFTY_SharedAncestor.putAsValue("' + name + '"): replacing an already-resolved record.');
        }
        ancestor.resolvedRecord = record;
        ancestor.resolvedBundle = null;
        ancestor.resolvedRecordIsPersisted = (record != null && record.Id != null);
        return ancestor;
    }

    /** Register just the Provider variant that generates the shared record. */
    public static XFTY_SharedAncestor put(String name, XFTY_LookupKeyIntf variantKey) {
        XFTY_SharedAncestor ancestor = get(name);
        ancestor.assertUnresolved('put(name, key)');
        ancestor.keyed('put(name, key)').withKey(variantKey);
        return ancestor;
    }

    /**
     * Register a fully-configured `XFTY_DummySObjectProvider` - value expressions,
     * `putRequired` / `includeOptional` / `put(path, ...)`, a pinned variant.
     * Not combined with the template / key forms.
     */
    public static XFTY_SharedAncestor put(String name, XFTY_DummySObjectProvider provider) {
        XFTY_SharedAncestor ancestor = get(name);
        ancestor.assertUnresolved('put(name, provider)');
        if (ancestor.source != null) {
            throw ancestor.notBoth('put(name, provider)');
        }
        ancestor.source = new XFTY_ConfiguredAncestorProvider(provider);
        return ancestor;
    }

    /** `put(name, record)` (same Id-disambiguation), applied only if `name` is not registered yet. */
    public static XFTY_SharedAncestor putIfAbsent(String name, SObject record) {
        XFTY_SharedAncestor ancestor = get(name);
        if (ancestor.isUnregistered()) {
            put(name, record);
        }
        return ancestor;
    }

    /** As {@link #putIfAbsent(String, SObject)}, pinning the variant instead of a template. */
    public static XFTY_SharedAncestor putIfAbsent(String name, XFTY_LookupKeyIntf variantKey) {
        XFTY_SharedAncestor ancestor = get(name);
        if (ancestor.isUnregistered()) {
            put(name, variantKey);
        }
        return ancestor;
    }

    /** Pin the Provider variant that generates this shared record. Chains off `putAsTemplate` / `put(name, record)`. */
    public XFTY_SharedAncestor fromVariant(XFTY_LookupKeyIntf variantKey) {
        this.assertUnresolved('fromVariant(...)');
        this.keyed('fromVariant(...)').withKey(variantKey);
        return this;
    }

    /** Copy this field from the shared record into the child's lookup, instead of its Id. Chains off any `put*`. */
    public XFTY_SharedAncestor copyingRelatedField(SObjectField relatedField) {
        this.assertUnresolved('copyingRelatedField(...)');
        this.relatedField = relatedField;
        return this;
    }

    /** Package-internal, for {@link XFTY_SharedAncestorResolver}: every registered ancestor not yet resolved. */
    public static List<XFTY_SharedAncestor> configuredUnresolved() {
        List<XFTY_SharedAncestor> pending = new List<XFTY_SharedAncestor>();
        for (XFTY_SharedAncestor ancestor : BY_NAME.values()) {
            if (ancestor.source != null && ancestor.resolvedRecord == null) {
                pending.add(ancestor);
            }
        }
        return pending;
    }

    private Boolean isUnregistered() {
        return this.source == null && this.resolvedRecord == null;
    }

    private XFTY_KeyedAncestorProvider keyed(String call) {
        if (this.source == null) {
            this.keyedSource = new XFTY_KeyedAncestorProvider(this.name);
            this.source = this.keyedSource;
        }
        if (this.keyedSource == null) {
            throw notBoth(call);
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

    private XFTY_DummySObjectFtyProviderException notBoth(String call) {
        return new XFTY_DummySObjectFtyProviderException(
                'Shared ancestor "' + this.name + '": use put(name, provider) OR putAsTemplate(...) / put(name, key), '
                        + 'not both (' + call + ') - the Provider carries its own template and variant.'
        );
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
                            + this.name + '", template / key / provider).'
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
        return (this.keyedSource != null) ? this.keyedSource.overrideTemplate() : null;
    }

    public SObjectField getRelatedField() {
        return this.relatedField;
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
        if (this.resolvedRecord == null) {
            XFTY_SharedAncestorResolver.resolveAllConfigured(context.providerLookup, context.insertMode);
        }
        if (this.resolvedRecord == null) {
            // Registered after the pre-phase ran (a later supply*() call) - resolve it alone.
            this.resolveNow(context.providerLookup, context.insertMode);
        }
        return this.resolvedRecord;
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
