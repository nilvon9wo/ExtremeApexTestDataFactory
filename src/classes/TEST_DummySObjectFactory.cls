@IsTest
public class TEST_DummySObjectFactory {
    public static TEST_DummySObjectBundle createBundle(
    	TEST_DummySObjectMasterTemplate masterTemplate,
    	List<SObject> testSpecificTemplateList,
    	TEST_InsertModeEnum insertMode,
    	TEST_InsertInclusivityEnum inclusivity 
    ) {
    	Integer quantity = testSpecificTemplateList.size();
    	TEST_DummySObjectBundle bundle 
    		= createRelatedRecords(masterTemplate, testSpecificTemplateList.size(), insertMode, inclusivity);  
    	
    	List<SObject> sobjectList = new List<SObject>();
    	for (SObject testSpecificTemplate : testSpecificTemplateList) {
    		sobjectList.add(cloneAndCompleteNonRelationshipValues(masterTemplate, testSpecificTemplate));
    	}
    	
    	bundle.put(masterTemplate.primaryTargetField, sobjectList);
    	createRelationships(bundle, masterTemplate, inclusivity);
    	
	    switch on insertMode {
	      when NOW { 
	        insert sobjectList; 
	      }
	      when RELATED_ONLY {
	        insert sobjectList;
	      }
	      when MOCK {
	        TEST_InsertMocker.addIds(sobjectList);
	      }
	    }
    	
    	return bundle;
    } 
    
	// Create related records --------------------------------------------------------------------------------
    
    private static TEST_DummySObjectBundle createRelatedRecords (
    	TEST_DummySObjectMasterTemplate masterTemplate,
    	Integer quantity,
    	TEST_InsertModeEnum insertMode,
    	TEST_InsertInclusivityEnum inclusivity 
    ) {
    	TEST_DummySObjectBundle bundle = new TEST_DummySObjectBundle(); 
    	if (TEST_InsertInclusivityEnum.NONE.equals(inclusivity)) {
    		return bundle;
    	}
    	
    	createRelatedRecords(bundle, quantity, masterTemplate.requiredRelationshipBySObjectFieldMap, insertMode, inclusivity);
    	if (!TEST_InsertInclusivityEnum.ALL.equals(inclusivity)) {
    		return bundle;
    	}

    	return createRelatedRecords(bundle, quantity, masterTemplate.optionalRelationshipBySObjectFieldMap, insertMode, inclusivity);
    }
    
    private static TEST_DummySObjectBundle createRelatedRecords(
    		TEST_DummySObjectBundle bundle,
	    	Integer quantity,
    		Map<SObjectField, TEST_DummyDefaultRelationshipIntf> relationshipsBySObjectField,
	    	TEST_InsertModeEnum insertMode,
    		TEST_InsertInclusivityEnum inclusivity
		) {
		for (SObjectField sObjectField : relationshipsBySObjectField.keySet()) {
			TEST_DummyDefaultRelationshipIntf relationshipTemplate =  relationshipsBySObjectField.get(sObjectField);
			SObject sObjectTemplate = relationshipTemplate.get();
			createRelatedRecords(bundle, quantity, sObjectField, sObjectTemplate, insertMode, inclusivity);
		} 
		return bundle;
	}
	
    private static TEST_DummySObjectBundle createRelatedRecords(
    		TEST_DummySObjectBundle bundle,
	    	Integer quantity,
    		SObjectField sObjectField,
    		SObject sObjectTemplate,
	    	TEST_InsertModeEnum insertMode,
    		TEST_InsertInclusivityEnum inclusivity
		) {
		TEST_DummySObjectFactoryOutletIntf factoryOutlet = TEST_DummySObjectFactoryOutletLookup.get(sObjectTemplate.getSObjectType());

		TEST_DummySObjectBundle innerBundle = factoryOutlet.createBundle(
			createClonedTemplateList(quantity, sObjectTemplate),
			(TEST_InsertModeEnum.RELATED_ONLY.equals(insertMode)) ? TEST_InsertModeEnum.NOW : insertMode,
			(TEST_InsertInclusivityEnum.PREVENT_CASCADE.equals(inclusivity)) ? TEST_InsertInclusivityEnum.NONE : inclusivity
		);

		return bundle.put(sObjectField, innerBundle)
			.put(sObjectField, innerBundle.getList(factoryOutlet.getPrimaryTargetField()));
	}
	
	
	private static List<SObject> createClonedTemplateList (Integer quantity, SObject sObjectTemplate) {
		List<SObject> clonedList = new List<SObject>();
		for (Integer i = 1; i <= quantity; i++) {
			clonedList.add(perfectClone(sObjectTemplate));
		}
		return clonedList;
	}
	
	// Setting Values --------------------------------------------------------------------------------

    public static SObject cloneAndCompleteNonRelationshipValues(TEST_DummySObjectMasterTemplate masterTemplate, SObject testSpecificTemplate) {
		SObject filledTemplate = perfectClone(testSpecificTemplate);
		for (SObjectField sObjectField : masterTemplate.defaultBySObjectFieldMap.keySet()) {
			if (filledTemplate.get(sObjectField) == null) {
				filledTemplate.put(sObjectField, masterTemplate.defaultBySObjectFieldMap.get(sObjectField).get());
			}
		}
		return filledTemplate;    	
    }
    
	private static TEST_DummySObjectBundle createRelationships(
			TEST_DummySObjectBundle bundle,
			TEST_DummySObjectMasterTemplate masterTemplate, 
			TEST_InsertInclusivityEnum inclusivity
		) {
		if (TEST_InsertInclusivityEnum.NONE.equals(inclusivity)) {
			return bundle;
		}
		
		List<SObject> sObjectList = bundle.getList(masterTemplate.primaryTargetField);
		for (Integer i = 0; i < sObjectList.size(); i++) {
			createRelationships(bundle, masterTemplate, sObjectList[i], i);
		}
		return bundle;
	}
	
	private static SObject createRelationships(
			TEST_DummySObjectBundle bundle, 
			TEST_DummySObjectMasterTemplate masterTemplate, 
			SObject sObj, 
			Integer i
		) {
		createRelationships(bundle, masterTemplate.requiredRelationshipBySObjectFieldMap.keySet(), sObj, i);
		createRelationships(bundle, masterTemplate.optionalRelationshipBySObjectFieldMap.keySet(), sObj, i);
		return sObj;
	}    
	
	private static SObject createRelationships(
			TEST_DummySObjectBundle bundle, 
			Set<SObjectField> sObjectFieldSet, 
			SObject sObj, 
			Integer i
		) {
		for(SObjectField sObjectField : sObjectFieldSet) {
			if(
				sObj.get(sObjectField) == null 
				&& bundle.getList(sObjectField) != null
				&& bundle.getList(sObjectField)[i] != null
			) {
				sObj.put(sObjectField, bundle.getList(sObjectField)[i].Id);
			}	 
		} 
		return sObj;
	}
	
	// Helpers --------------------------------------------------------------------------------
	
	private static SObject perfectClone(SObject sObj) {
		return sObj.clone(true, true, true, true);
	}
	
}
