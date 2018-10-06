@IsTest
public class XFTY_DummySObjectSupplier {
	private SObjectType sObjectType;

	private static final Boolean NO_CONFLICT = true;
	
	public XFTY_DummySObjectSupplier(SObjectType sObjectType) {
		if (SObjectType == null) {
			throw new SanityException('It is required to specify an SObjectType to request supplies!');
		}
		this.sObjectType = sObjectType;
	}
	
	private List<SObject> overrideTemplateList;
	private Integer quantityPerListedTemplate = 1; // If no templates are supplied, a blank one will be created. 
	private XFTY_InsertModeEnum insertMode = XFTY_InsertModeEnum.NEVER;
	private XFTY_InsertInclusivityEnum inclusivity = XFTY_InsertInclusivityEnum.NONE;
	private Boolean hasCustomMasterTemplate = false;
	
	private XFTY_DummySObjectFactoryOutletIntf factoryOutlet {
		get {
			if (this.factoryOutlet == null) {
				if (this.sObjectType == null) {
					throw new IndeterminateSObjectTypeException('SObjectType must be set before retreiving its factory.');
				}
				this.factoryOutlet = XFTY_DummySObjectFactoryOutletLookup.get(this.sObjectType);
			}
			return this.factoryOutlet;
		}
		private set;
	}
	
	private XFTY_DummySObjectMasterTemplate masterTemplate {
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
	
	public XFTY_DummySObjectSupplier setQuantityPerTemplate(Integer quantityPerListedTemplate) {
		if (quantityPerListedTemplate < 1) {
			throw new SanityException('It makes no sense to supply ' + quantityPerListedTemplate);
		}
		this.quantityPerListedTemplate = quantityPerListedTemplate;
		return this;
	}

	public XFTY_DummySObjectSupplier setOverrideTemplateList(List<SObject> overrideTemplateList) {
		if (overrideTemplateList != null && !overrideTemplateList.isEmpty()) {
			this.sObjectType = overrideTemplateList[0].getSObjectType();
		}

		this.overrideTemplateList = overrideTemplateList;
		this.checkForSObjectTypeConflict(overrideTemplateList);
		return this;
	}

	public XFTY_DummySObjectSupplier setOverrideTemplate(SObject overrideTemplate) {
		return this.setOverrideTemplateList(new List<SObject>{overrideTemplate});
	}

	public XFTY_DummySObjectSupplier setInsertMode(XFTY_InsertModeEnum insertMode) {
		this.insertMode = insertMode;
		return this;
	}

	public XFTY_DummySObjectSupplier setInclusivity(XFTY_InsertInclusivityEnum inclusivity) {
		this.inclusivity = inclusivity;
		return this; 
	}

	// Include methods ----------------------------------------------------------------------------------------------------------
	// Use these when static templates are insufficent (e.g. because unique values are required).
	// WARNING: You can use both override templates and include methods, but in the event of conflicting values, override values will win!
	
    public XFTY_DummySObjectSupplier put(SObjectField sObjectField, XFTY_DummyDefaultValueIntf valueTemplate) {
    	this.masterTemplate.put(sObjectField, valueTemplate); 
    	this.hasCustomMasterTemplate = true;
    	return this;
    } 

    public XFTY_DummySObjectSupplier put(SObjectField sObjectField, XFTY_DummyDefaultRelationshipRequired relationshipTemplate) {
    	this.masterTemplate.put(sObjectField, relationshipTemplate); 
    	this.hasCustomMasterTemplate = true;
    	return this;
    }

    public XFTY_DummySObjectSupplier put(SObjectField sObjectField, XFTY_DummyDefaultRelationshipOptional relationshipTemplate) {
    	this.masterTemplate.put(sObjectField, relationshipTemplate); 
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
			? new List<SObject>{this.SObjectType.newSObject()} 
			: this.overrideTemplateList;

		// 			
		List<SObject> multipliedTemplateList = (this.quantityPerListedTemplate > 1)
			? this.multiplyByQuantity(templateList)
			: templateList;

		// We can't check this.masterTemplate for null because getting it will set it, so it should never be null.
		return (this.hasCustomMasterTemplate == null)
			? XFTY_DummySObjectFactory.createBundle(this.masterTemplate, multipliedTemplateList, insertMode, inclusivity)
			: this.factoryOutlet.createBundle(multipliedTemplateList, insertMode, inclusivity);
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
	
	// Consistancy checks ----------------------------------------------------------------
	
	private Boolean checkForSObjectTypeConflict(List<SObject> overrideTemplateList) {
		if (
			this.overrideTemplateList != null 
			&& !this.overrideTemplateList.isEmpty()
			) {
			for(SObject overrideTemplate : overrideTemplateList) {
				if (overrideTemplate.getSObjectType() != sObjectType) {
					throw new ConflictException('SObjectType ' + sObjectType + ' is not matched by template: ' + overrideTemplate);
				}
			}
		}
		return NO_CONFLICT;	
	}
	
	// Exceptions checks ----------------------------------------------------------------

    public class SanityException extends Exception{}
    public class ConflictException extends Exception{}
    public class IndeterminateSObjectTypeException extends Exception{}
}