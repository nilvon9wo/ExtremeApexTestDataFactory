/**
 * One record shared by every relationship that references it - the same instance
 * and Id everywhere, generated at most once per test method.
 *
 * ```apex
 * XFTY_SharedAncestor.get('acme-hq').of(new Account(Name = 'ACME HQ'));
 *
 * new XFTY_DummySObjectMasterTemplate(Contact.Id)
 *     .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('acme-hq'));
 * ```
 *
 * Flyweight - obtain instances with `get(name)`, never `new`. State is static and
 * resets between test methods. Configure with `of(...)` / `withKey(...)`, or
 * `suppliedBy(...)` for the full generation API; {@link XFTY_SharedAncestorResolver}
 * resolves every configured ancestor before the first `supply*()` call.
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

    // Registry ------------------------------------------------------------

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

    /** `get(name)`, applying `template` only if it is not configured yet (for a setup helper that may run twice). */
    public static XFTY_SharedAncestor getOrElse(String name, SObject template) {
        XFTY_SharedAncestor ancestor = get(name);
        if (ancestor.source == null && ancestor.resolvedRecord == null) {
            ancestor.of(template);
        }
        return ancestor;
    }

    /** As {@link #getOrElse(String, SObject)}, pinning the variant instead of a template. */
    public static XFTY_SharedAncestor getOrElse(String name, XFTY_LookupKeyIntf variantKey) {
        XFTY_SharedAncestor ancestor = get(name);
        if (ancestor.source == null && ancestor.resolvedRecord == null) {
            ancestor.withKey(variantKey);
        }
        return ancestor;
    }

    /** Register a record the test built itself. WARNs if it replaces a different, already-resolved one. */
    public static void put(String name, SObject record) {
        XFTY_SharedAncestor ancestor = get(name);
        if (ancestor.resolvedRecord != null && ancestor.resolvedRecord != record) {
            System.debug(LoggingLevel.WARN,
                    'XFTY_SharedAncestor.put("' + name + '"): replacing an already-resolved record.');
        }
        ancestor.resolvedRecord = record;
        ancestor.resolvedBundle = null;
        ancestor.resolvedRecordIsPersisted = (record != null && record.Id != null);
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

    /** Package-internal, for {@link XFTY_SharedAncestorResolver}: every configured ancestor not yet resolved. */
    public static List<XFTY_SharedAncestor> configuredUnresolved() {
        List<XFTY_SharedAncestor> pending = new List<XFTY_SharedAncestor>();
        for (XFTY_SharedAncestor ancestor : BY_NAME.values()) {
            if (ancestor.source != null && ancestor.resolvedRecord == null) {
                pending.add(ancestor);
            }
        }
        return pending;
    }

    // Configuration -----------------------------------------------------
    //
    // of / withKey build a XFTY_KeyedAncestorProvider; suppliedBy builds a
    // XFTY_ConfiguredAncestorProvider. Mutually exclusive; copyingRelatedField
    // composes with either.

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
     * value strategies, `putRequired` / `includeOptional` / `put(path, ...)`, a
     * pinned variant. Not combined with `of(...)` / `withKey(...)`.
     */
    public XFTY_SharedAncestor suppliedBy(XFTY_DummySObjectProvider provider) {
        this.assertUnresolved('suppliedBy(...)');
        if (this.source != null) {
            throw notBoth('suppliedBy(...)');
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
                'Shared ancestor "' + this.name + '": use suppliedBy(provider) OR of(...) / withKey(...), not both '
                        + '(' + call + ') - the Provider carries its own template and variant.'
        );
    }

    // Resolution ------------------------------------------------------

    /** Resolve now - e.g. to read `getId(name)` before any `supply*()` call. */
    public XFTY_SharedAncestor resolveNow(XFTY_DummySObjectProviderLookupIntf lookup, XFTY_InsertModeEnum insertMode) {
        if (this.resolvedRecord == null) {
            new XFTY_SharedAncestorResolver(lookup, insertMode).resolve(new List<XFTY_SharedAncestor>{ this });
        }
        return this;
    }

    /** Package-internal, for {@link XFTY_SharedAncestorResolver}: the recipe for this ancestor's record. */
    public XFTY_SharedAncestorProvider source() {
        if (this.source == null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + this.name + '" was never configured - call get("' + this.name
                            + '").of(...), .withKey(...), or .suppliedBy(...).'
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
            // Configured after the pre-phase ran (a later supply*() call) - resolve it alone.
            this.resolveNow(context.providerLookup, context.insertMode);
        }
        return this.resolvedRecord;
    }

    /**
     * The shared record as a single-record sub-bundle, so `getBundle(field)` and
     * `getList(field)` stay consistent. For a `put(name, record)` record, one is
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
