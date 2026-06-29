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
                if (this.sObjectType == null) {
                    throw new IndeterminateSObjectTypeException('SObjectType must be set before retrieving its factory.');
                }
                this.factoryOutlet = this.sObjectProviderLookup.get(this.sObjectType);
            }
            return this.factoryOutlet;
        }
        private set;
    }

    private final XFTY_DummySObjectMasterTemplate masterTemplate {
        get {
            if (this.masterTemplate == null) {
                if (this.sObjectType == null) {
                    throw new IndeterminateSObjectTypeException('SObjectType must be set before including default values on the master template.');
                }
                this.masterTemplate = this.factoryOutlet.getMasterTemplate()
                        .clone();
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

    public XFTY_DummySObjectProvider put(SObjectField sObjectField, XFTY_DummyDefaultRelationshipRequired relationshipTemplate) {
        this.masterTemplate.remove(sObjectField);
        this.masterTemplate.put(sObjectField, relationshipTemplate);
        this.hasCustomMasterTemplate = true;
        return this;
    }

    public XFTY_DummySObjectProvider put(SObjectField sObjectField, XFTY_DummyDefaultRelationshipOptional relationshipTemplate) {
        this.masterTemplate.remove(sObjectField);
        this.masterTemplate.put(sObjectField, relationshipTemplate);
        this.hasCustomMasterTemplate = true;
        return this;
    }

    //noinspection ApexUnusedDeclaration
    public XFTY_DummySObjectProvider removeFromMasterTemplate(SObjectField sObjectField){
        this.masterTemplate.remove(sObjectField);
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

        // We can't check this.masterTemplate for null because getting it will set it, so it should never be null.
        XFTY_DummySObjectBundle bundle = (this.hasCustomMasterTemplate == null)
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
    public class IndeterminateSObjectTypeException extends Exception {
    }
}