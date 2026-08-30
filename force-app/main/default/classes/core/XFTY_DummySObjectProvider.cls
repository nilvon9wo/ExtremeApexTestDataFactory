/**
 * This class is responsible for providing test data.
 *
 * It provides the primary entry point for the Extreme Apex Test Data Factory,
 * from which this code is adapted.
 * @see <a href="https://github.com/nilvon9wo/ExtremeApexTestDataFactory/">ExtremeApexTestDataFactory GitHub Repo</a>
 *
 * WARNING:
 * Because Salesforce `@TestSetup` is quirky (and arguably not such a great practice as
 * Salesforce would have developers believe), using this framework with `@TestSetup`
 * is not supported.  Specifically, there is a known issue with `@TestSetup` resetting
 * static variables which this framework depends upon.
 * (These variables do NOT allow communication between each test ALWAYS runs in separate context!)
 */
@IsTest
public class XFTY_DummySObjectProvider {
    private SObjectType sObjectType;
    private final XFTY_DummySObjectProviderLookupIntf sObjectProviderLookup;

    private static final Boolean NO_CONFLICT = true;

    public XFTY_DummySObjectProvider(SObjectType sObjectType, XFTY_DummySObjectProviderLookupIntf sObjectProviderLookup) {
        if (sObjectType == null) {
            throw new SanityException('It is required to specify an SObjectType to request data!');
        }
        this.sObjectType = sObjectType;

        if (sObjectProviderLookup == null) {
            throw new SanityException('It is required to specify an Dummy SObject Provider Lookup to request data!');
        }
        this.sObjectProviderLookup = sObjectProviderLookup;
    }

    /**
     * Convenience: start from a lookup key. The `SObjectType` is taken from the
     * key and the key is pinned as the variant (equivalent to
     * `new XFTY_DummySObjectProvider(key.getSObjectType(), lookup).withVariant(key)`).
     */
    public XFTY_DummySObjectProvider(XFTY_LookupKeyIntf variantKey, XFTY_DummySObjectProviderLookupIntf sObjectProviderLookup) {
        this(typeOf(variantKey), sObjectProviderLookup);
        this.explicitVariantKey = variantKey;
    }

    /**
     * Convenience: start from an override template. The `SObjectType` is taken
     * from the template and the template becomes the (single) override template,
     * so the variant is resolved from it too - equivalent to
     * `new XFTY_DummySObjectProvider(template.getSObjectType(), lookup).setOverrideTemplate(template)`.
     */
    public XFTY_DummySObjectProvider(SObject overrideTemplate, XFTY_DummySObjectProviderLookupIntf sObjectProviderLookup) {
        this(new List<SObject>{ overrideTemplate }, sObjectProviderLookup);
    }

    /**
     * Convenience: start from a list of override templates. The `SObjectType` is
     * taken from the first template - equivalent to
     * `new XFTY_DummySObjectProvider(list[0].getSObjectType(), lookup).setOverrideTemplateList(list)`.
     */
    public XFTY_DummySObjectProvider(List<SObject> overrideTemplateList, XFTY_DummySObjectProviderLookupIntf sObjectProviderLookup) {
        this(typeOf(overrideTemplateList), sObjectProviderLookup);
        this.setOverrideTemplateList(overrideTemplateList);
    }

    private static SObjectType typeOf(XFTY_LookupKeyIntf variantKey) {
        if (variantKey == null) {
            throw new SanityException('It is required to specify a lookup key to request data!');
        }
        return variantKey.getSObjectType();
    }

    private static SObjectType typeOf(List<SObject> overrideTemplateList) {
        if (overrideTemplateList == null || overrideTemplateList.isEmpty() || overrideTemplateList[0] == null) {
            throw new SanityException(
                    'Cannot derive an SObjectType from an empty or null template list - '
                            + 'supply at least one concrete template, or use the (SObjectType, lookup) constructor.'
            );
        }
        return overrideTemplateList[0].getSObjectType();
    }

    private List<SObject> overrideTemplateList;
    private XFTY_LookupKeyIntf explicitVariantKey;
    private Integer quantityPerListedTemplate = 1; // If no templates are supplied, a blank one will be created.
    private XFTY_InsertModeEnum insertMode = XFTY_InsertModeEnum.NEVER;
    private XFTY_InsertInclusivityEnum inclusivity = XFTY_InsertInclusivityEnum.NONE;
    private Boolean hasCustomMasterTemplate = false;

    // `sObjectType` is set non-null by the constructor and only ever reassigned
    // (in setOverrideTemplateList) to another SObject's type, which is never
    // null; the class is not subclassable. So these getters never see a null
    // type - no guard is needed. If a "construct now, set the type later" flow
    // is ever added, reinstate a guard + a dedicated exception here.

    private final XFTY_DummySobjectProviderIntf factoryOutlet {
        get {
            if (this.factoryOutlet == null) {
                this.factoryOutlet = this.sObjectProviderLookup.get(this.resolveVariantKey());
            }
            return this.factoryOutlet;
        }
        private set;
    }

    /**
     * Which Provider variant to use: an explicit key from `withVariant(...)`, or
     * the key derived from the first override template (so a template carrying a
     * record type reaches the matching Provider), or the plain SObjectType key.
     *
     * Only consulted the first time the Provider is resolved - if `put(...)` /
     * `removeFromMasterTemplate(...)` has already run, the variant is fixed;
     * `withVariant(...)` therefore rejects a late call.
     */
    private XFTY_LookupKeyIntf resolveVariantKey() {
        if (this.explicitVariantKey != null) {
            return this.explicitVariantKey;
        }
        if (this.overrideTemplateList != null && !this.overrideTemplateList.isEmpty()) {
            return XFTY_ProviderLookups.resolve(this.sObjectProviderLookup, this.overrideTemplateList[0]);
        }
        return XFTY_LookupKey.get(this.sObjectType);
    }

    private final XFTY_DummySObjectMasterTemplate masterTemplate {
        get {
            if (this.masterTemplate == null) {
                this.masterTemplate = this.factoryOutlet.getMasterTemplate()
                        .copy();
            }
            return this.masterTemplate;
        }
        private set;
    }

    //  Setters -----------------------------------------------------------------------------------------------------------------

    public XFTY_DummySObjectProvider setQuantityPerTemplate(Integer quantityPerListedTemplate) {
        if (quantityPerListedTemplate < 1) {
            throw new SanityException('It makes no sense to supply ' + quantityPerListedTemplate);
        }
        this.quantityPerListedTemplate = quantityPerListedTemplate;
        return this;
    }

    public XFTY_DummySObjectProvider setOverrideTemplateList(List<SObject> overrideTemplateList) {
        if (overrideTemplateList != null && !overrideTemplateList.isEmpty()) {
            this.sObjectType = overrideTemplateList[0].getSObjectType();
        }

        this.overrideTemplateList = overrideTemplateList;
        this.checkForSObjectTypeConflict(overrideTemplateList);
        return this;
    }

    public XFTY_DummySObjectProvider setOverrideTemplate(SObject overrideTemplate) {
        return this.setOverrideTemplateList(new List<SObject>{
                overrideTemplate
        });
    }

    /**
     * Pin the Provider variant explicitly (e.g.
     * `XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'PersonAccount')`),
     * instead of letting it be derived from the override template. Must be called
     * before any `put(...)` / `removeFromMasterTemplate(...)`, and the key must be
     * for this Provider's `SObjectType`.
     */
    public XFTY_DummySObjectProvider withVariant(XFTY_LookupKeyIntf variantKey) {
        if (this.hasCustomMasterTemplate) {
            // put(...) already resolved the Provider from the default variant.
            throw new SanityException('Call withVariant(...) before customizing the template with put(...).');
        }
        this.assertVariantKeyMatchesType(variantKey);
        this.explicitVariantKey = variantKey;
        return this;
    }

    private void assertVariantKeyMatchesType(XFTY_LookupKeyIntf variantKey) {
        if (variantKey == null) {
            throw new SanityException('A variant key is required.');
        }
        if (variantKey.getSObjectType() != this.sObjectType) {
            throw new ConflictException(
                    'Variant key is for ' + variantKey.getSObjectType()
                            + ' but this Provider requests ' + this.sObjectType + '.'
            );
        }
    }

    public XFTY_DummySObjectProvider setInsertMode(XFTY_InsertModeEnum insertMode) {
        this.insertMode = insertMode;
        return this;
    }

    public XFTY_DummySObjectProvider setInclusivity(XFTY_InsertInclusivityEnum inclusivity) {
        this.inclusivity = inclusivity;
        return this;
    }

    // Include methods ----------------------------------------------------------------------------------------------------------
    // Use these when static templates are insufficient (e.g. because unique values are required).
    // WARNING: You can use both override templates and include methods, but in the event of conflicting values, override values will win!

    public XFTY_DummySObjectProvider put(SObjectField sObjectField, XFTY_DummyDefaultValueIntf valueTemplate) {
        this.masterTemplate.remove(sObjectField);
        this.masterTemplate.put(sObjectField, valueTemplate);
        this.hasCustomMasterTemplate = true;
        return this;
    }

    public XFTY_DummySObjectProvider putRequired(SObjectField sObjectField, XFTY_DummyDefaultRelationshipIntf relationshipTemplate) {
        this.masterTemplate.remove(sObjectField);
        this.masterTemplate.putRequired(sObjectField, relationshipTemplate);
        this.hasCustomMasterTemplate = true;
        return this;
    }

    public XFTY_DummySObjectProvider putOptional(SObjectField sObjectField, XFTY_DummyDefaultRelationshipIntf relationshipTemplate) {
        this.masterTemplate.remove(sObjectField);
        this.masterTemplate.putOptional(sObjectField, relationshipTemplate);
        this.hasCustomMasterTemplate = true;
        return this;
    }

    /**
     * Convenience overload mirroring `XFTY_DummySObjectMasterTemplate.put(SObjectField, Object)`:
     * a bare literal is wrapped in `XFTY_DummyDefaultValueExact`; a value strategy
     * is routed to its typed overload. Relationships are rejected - use
     * `putRequired(...)` / `putOptional(...)`.
     */
    public XFTY_DummySObjectProvider put(SObjectField sObjectField, Object value) {
        if (value instanceof XFTY_DummyDefaultValueIntf) {
            return this.put(sObjectField, (XFTY_DummyDefaultValueIntf) value);
        }
        if (value instanceof XFTY_DummyDefaultRelationshipIntf) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Relationships must be added with putRequired(...) or putOptional(...), not put(...).'
            );
        }
        return this.put(sObjectField, new XFTY_DummyDefaultValueExact(value));
    }

    //noinspection ApexUnusedDeclaration
    public XFTY_DummySObjectProvider removeFromMasterTemplate(SObjectField sObjectField){
        this.masterTemplate.remove(sObjectField);
        this.hasCustomMasterTemplate = true;
        return this;
    }

    // Per-call relationship control ------------------------------------------------------------------------------------------
    // Both act only on THIS Provider instance (its own copy of the Master Template) - a
    // different Provider sharing the same static Master Template is unaffected. Call
    // before customizing with put(...) (same rule as withVariant).

    /**
     * Generate one specific *optional* relationship on this call, on top of
     * whatever `setInclusivity(...)` covers - i.e. promote it to required for this
     * instance. Throws if `sObjectField` is not an optional relationship on this
     * Provider.
     */
    public XFTY_DummySObjectProvider includeOptional(SObjectField sObjectField) {
        XFTY_DummyDefaultRelationshipIntf relationship =
                this.masterTemplate.optionalRelationshipBySObjectFieldMap.get(sObjectField);
        if (relationship == null) {
            throw new SanityException(
                    'includeOptional(' + sObjectField + '): ' + this.sObjectType
                            + ' has no optional relationship on that field.'
            );
        }
        this.masterTemplate.remove(sObjectField);
        this.masterTemplate.putRequired(sObjectField, relationship);
        this.hasCustomMasterTemplate = true;
        return this;
    }

    /**
     * Do not generate one specific relationship on this call - required or
     * optional. For this instance the relationship becomes non-existent: not
     * generated, not attached, not left as an orphan. Throws if `sObjectField` is
     * not a relationship on this Provider (use `removeFromMasterTemplate(...)` for
     * plain value fields).
     */
    public XFTY_DummySObjectProvider excludeRelationship(SObjectField sObjectField) {
        Boolean isRelationship =
                this.masterTemplate.requiredRelationshipBySObjectFieldMap.containsKey(sObjectField)
                        || this.masterTemplate.optionalRelationshipBySObjectFieldMap.containsKey(sObjectField);
        if (!isRelationship) {
            throw new SanityException(
                    'excludeRelationship(' + sObjectField + '): ' + this.sObjectType
                            + ' has no relationship on that field.'
            );
        }
        this.masterTemplate.remove(sObjectField);
        this.hasCustomMasterTemplate = true;
        return this;
    }

    // Supply methods ----------------------------------------------------------------------------------------------------------

    public XFTY_DummySObjectBundle supplyBundle() {
        if (this.hasCustomMasterTemplate && this.overrideTemplateList != null && !this.overrideTemplateList.isEmpty()) {
            System.debug(LoggingLevel.WARN, '!!!  When using both customer master and overrides, overrides will win all conflicts! !!!');
        }

        // Factory requires at least one instance of SObject to merge values from master template.
        List<SObject> templateList = (this.overrideTemplateList == null || this.overrideTemplateList.isEmpty())
                ? new List<SObject>{
                        this.sObjectType.newSObject()
                }
                : this.overrideTemplateList;

        //
        List<SObject> multipliedTemplateList = (this.quantityPerListedTemplate > 1)
                ? this.multiplyByQuantity(templateList)
                : templateList;

        XFTY_GenerationContext context = new XFTY_GenerationContext(
                this.sObjectProviderLookup, this.insertMode, this.inclusivity
        );

        // When the caller has customized the master template via put(...) / removeFromMasterTemplate(...),
        // generate from that customized copy. Otherwise delegate to the Provider, which may apply its own
        // generation logic (e.g. selecting a template by record type).
        XFTY_DummySObjectBundle bundle = this.hasCustomMasterTemplate
                ? XFTY_DummySObjectFactory.createBundle(context, this.masterTemplate, multipliedTemplateList)
                : this.factoryOutlet.createBundle(context, multipliedTemplateList);
        return bundle;
    }

    private List<SObject> multiplyByQuantity(List<SObject> templateList) {
        List<SObject> multipliedTemplateList = new List<SObject>();
        for (Integer i = 1; i <= this.quantityPerListedTemplate; i++) {
            multipliedTemplateList.addAll(templateList.clone());
        }
        return multipliedTemplateList;
    }

    public List<SObject> supplyList() {
        return this.supplyBundle()
                .getList(this.factoryOutlet.getPrimaryTargetField());
    }

    public SObject supply() {
        return this.supplyList()[0];
    }

    // Consistency checks ----------------------------------------------------------------

    private Boolean checkForSObjectTypeConflict(List<SObject> overrideTemplateList) {
        if (
                this.overrideTemplateList != null
                        && !this.overrideTemplateList.isEmpty()
        ) {
            for (SObject overrideTemplate : overrideTemplateList) {
                if (overrideTemplate.getSObjectType() != sObjectType) {
                    throw new ConflictException('SObjectType ' + sObjectType + ' is not matched by template: ' + overrideTemplate);
                }
            }
        }
        return NO_CONFLICT;
    }

    // Exceptions checks ----------------------------------------------------------------

    public class SanityException extends Exception {
    }
    public class ConflictException extends Exception {
    }
}