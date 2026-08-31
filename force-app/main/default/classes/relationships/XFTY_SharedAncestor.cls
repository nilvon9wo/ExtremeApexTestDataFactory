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
 * This is the **on-demand** kind (design doc decision 9): lightweight, resolved
 * inline the first time it is referenced, and it must have no ancestors of its
 * own - a shared ancestor that references itself (directly or through its
 * Provider's relationships) throws rather than recursing. Deep / declared
 * ancestors and DML-batched resolution are a later increment - see
 * docs/roadmap/shared-ancestors.md.
 */
@IsTest
public class XFTY_SharedAncestor implements XFTY_SharedRelationshipIntf {
    private static final Map<String, XFTY_SharedAncestor> BY_NAME = new Map<String, XFTY_SharedAncestor>();

    private final String name;
    private SObject overrideTemplate;
    private XFTY_LookupKeyIntf explicitLookupKey;
    private SObjectField relatedField;
    private XFTY_LookupKeyIntf resolvedLookupKey;
    private SObject resolvedRecord;
    private XFTY_DummySObjectBundle resolvedBundle;
    private Boolean resolvedRecordIsPersisted = false;
    private Boolean resolutionInProgress = false;

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
                            + 'supply*() call first, or register a record with XFTY_SharedAncestor.put("' + name + '", record).'
            );
        }
        return ancestor.resolvedRecord.Id;
    }

    // Configuration ----------------------------------------------------------

    /** The override template for the shared record; also identifies its SObject type. */
    public XFTY_SharedAncestor of(SObject overrideTemplate) {
        this.assertUnresolved('of(...)');
        this.overrideTemplate = overrideTemplate;
        return this;
    }

    /** Pin the Provider variant that generates the shared record. */
    public XFTY_SharedAncestor withKey(XFTY_LookupKeyIntf lookupKey) {
        this.assertUnresolved('withKey(...)');
        this.explicitLookupKey = lookupKey;
        return this;
    }

    /** Copy this field from the shared record into the child's lookup, instead of its Id. */
    public XFTY_SharedAncestor copyingRelatedField(SObjectField relatedField) {
        this.assertUnresolved('copyingRelatedField(...)');
        this.relatedField = relatedField;
        return this;
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
        return this.overrideTemplate;
    }

    public SObjectField getRelatedField() {
        return this.relatedField;
    }

    public XFTY_LookupKeyIntf resolveLookupKey(XFTY_DummySObjectProviderLookupIntf providerLookup) {
        if (this.resolvedLookupKey == null) {
            this.resolvedLookupKey = (this.explicitLookupKey != null)
                    ? this.explicitLookupKey
                    : XFTY_ProviderLookups.resolve(providerLookup, this.requireTemplate());
        }
        return this.resolvedLookupKey;
    }

    // XFTY_SharedRelationshipIntf ----------------------------------------

    public String getSharedName() {
        return this.name;
    }

    public SObject resolveSharedRecord(XFTY_GenerationContext context) {
        if (this.resolvedRecord != null) {
            return this.resolvedRecord;
        }
        this.assertNotAlreadyResolving();
        this.resolutionInProgress = true;
        try {
            this.generateSharedRecord(context);
        } finally {
            this.resolutionInProgress = false;
        }
        return this.resolvedRecord;
    }

    private void assertNotAlreadyResolving() {
        if (!this.resolutionInProgress) {
            return;
        }
        throw new XFTY_DummySObjectFtyProviderException(
                'Shared ancestor "' + this.name + '" references itself while resolving - directly, through a '
                        + 'relationship on its own Provider, or round a chain of other shared ancestors - a cycle. '
                        + 'An on-demand shared ancestor must be lightweight with no ancestors of its own; break the '
                        + 'cycle by registering one side with XFTY_SharedAncestor.put("' + this.name + '", record).'
        );
    }

    private void generateSharedRecord(XFTY_GenerationContext context) {
        XFTY_GenerationContext ancestorContext = context.forRelated();
        XFTY_DummySobjectProviderIntf provider =
                context.providerLookup.get(this.resolveLookupKey(context.providerLookup));
        this.resolvedBundle = provider.createBundle(
                ancestorContext,
                new List<SObject>{ this.requireTemplate().clone(true, true, true, true) }
        );
        this.resolvedRecord = this.resolvedBundle.getList(provider.getPrimaryTargetField())[0];
        this.resolvedRecordIsPersisted = XFTY_InsertModeEnum.NOW == ancestorContext.insertMode;
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

    private SObject requireTemplate() {
        if (this.overrideTemplate == null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + this.name + '" was never configured. Call '
                            + 'XFTY_SharedAncestor.get("' + this.name + '").of(new SomeSObject()) before generating.'
            );
        }
        return this.overrideTemplate;
    }
}
