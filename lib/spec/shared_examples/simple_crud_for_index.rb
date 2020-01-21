shared_examples 'simple crud for index' do
  describe 'GET #index' do
    let(:created_models) { create_list(model_class, 10) }

    before { created_models }

    context 'without authenticated user' do
      subject!(:req) { get :index }

      include_examples 'unauthorized when not logged in' if check_authenticate(:create)
    end

    if check_authorize(:create)
      context 'when not authorized' do
        subject!(:req) { get :index }

        it 'fails with unauthorized' do
          make_policies_fail(:index)
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'with authenticated user' do
      include_context 'with authenticated user' if check_authenticate(:index)
      before do
        make_policies_succeed(:index)
        get :index
      end

      if check_paginate(:index)
        ### TODO: fix
        it 'renders models correctly serialized' do
          # expect(response_body).to have_been_serialized_with(model_serializer).to_json
        end

        it 'renders the correct models' do
          byebug
          expect(response_body['page'].map { |a| a['id'] }).to eq(model_class_object.all.map(&:id))
        end

        if check_filter(:index)
          it 'renders the filtered models' do
            expect(model_class_object).to receive(:filter)
            get :index
          end
        end

      else
        it 'renders models correctly serialized' do
          ### TODO: fix
          # expect(response_body['page']).to have_been_serialized_with(model_serializer).to_json
        end

        it 'renders the correct models' do
          ids = response_body.map { |a| a['id'] }
          expect(ids).to eq(model_class_object.all.map(&:id).take(ids.count))
        end

        if check_filter(:index)
          it 'renders the filtered models' do
            expect_any_instance_of(model_class_object).to receive(:filter)
            get :index
          end
        end
      end
    end
  end
end
