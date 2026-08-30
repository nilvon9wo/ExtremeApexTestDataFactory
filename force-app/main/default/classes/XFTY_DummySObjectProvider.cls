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

    private List<SObject> overrideTemplateList;
    private Integer quantityPerListedTemplate = 1; // If no templates are supplied, a blank one will be created.
    private XFTY_InsertModeEnum insertMode = XFTY_InsertModeEnum.NEVER;
    private XFTY_InsertInclusivityEnum inclusivity = XFTY_InsertInclusivityEnum.NONE;
    private Boolean hasCustomMasterTemplate = false;

    private final XFTY_DummySobjectProviderIntf factoryOutlet {
        get {
            if (this.factoryOutlet == null) {
                this.factoryOutlet = this.sObjectProviderLookup.get(this.sObjectType);
            }
            return this.factoryOutlet;
        }
        private set;
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

        // When the caller has customized the master template via put(...) / removeFromMasterTemplate(...),
        // generate from that customized copy. Otherwise delegate to the Provider, which may apply its own
        // generation logic (e.g. selecting a template by record type).
        XFTY_DummySObjectBundle bundle = this.hasCustomMasterTemplate
                ? XFTY_DummySObjectFactory.createBundle(
                        this.sObjectProviderLookup,
                        this.masterTemplate,
                        multipliedTemplateList,
                        insertMode,
                        inclusivity
                )
                : this.factoryOutlet.createBundle(this.sObjectProviderLookup, multipliedTemplateList, insertMode, inclusivity);
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