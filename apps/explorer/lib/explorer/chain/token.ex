defmodule Explorer.Chain.Token do
  @moduledoc """
  Represents a token.

  ## Token Indexing

  The following types of tokens are indexed:

  * RAMA-20
  * RAMA-721

  ## Token Specifications

  * [RAMA-20](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md)
  * [RAMA-721](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md)
  * [RAMA-777](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-777.md)
  * [RAMA-1155](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1155.md)
  """

  use Explorer.Schema

  import Ecto.{Changeset, Query}

  alias Ecto.Changeset
  alias Explorer.Chain.{Address, Hash, Token}

  @typedoc """
  * `name` - Name of the token
  * `symbol` - Trading symbol of the token
  * `total_supply` - The total supply of the token
  * `decimals` - Number of decimal places the token can be subdivided to
  * `type` - Type of token
  * `calatoged` - Flag for if token information has been cataloged
  * `contract_address` - The `t:Address.t/0` of the token's contract
  * `contract_address_hash` - Address hash foreign key
  * `holder_count` - the number of `t:Explorer.Chain.Address.t/0` (except the burn address) that have a
    `t:Explorer.Chain.CurrentTokenBalance.t/0` `value > 0`.  Can be `nil` when data not migrated.
  * `bridged` - Flag for bridged tokens from other chain
  """
  @type t :: %Token{
          name: String.t(),
          symbol: String.t(),
          total_supply: Decimal.t(),
          decimals: non_neg_integer(),
          type: String.t(),
          cataloged: boolean(),
          contract_address: %Ecto.Association.NotLoaded{} | Address.t(),
          contract_address_hash: Hash.Address.t(),
          holder_count: non_neg_integer() | nil,
          bridged: boolean()
        }

  @derive {Poison.Encoder,
           except: [
             :__meta__,
             :contract_address,
             :inserted_at,
             :updated_at
           ]}

  @derive {Jason.Encoder,
           except: [
             :__meta__,
             :contract_address,
             :inserted_at,
             :updated_at
           ]}

  @primary_key false
  schema "tokens" do
    field(:name, :string)
    field(:symbol, :string)
    field(:total_supply, :decimal)
    field(:decimals, :decimal)
    field(:type, :string)
    field(:cataloged, :boolean)
    field(:holder_count, :integer)
    field(:bridged, :boolean)

    belongs_to(
      :contract_address,
      Address,
      foreign_key: :contract_address_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Address
    )

    timestamps()
  end

  @required_attrs ~w(contract_address_hash type)a
  @optional_attrs ~w(cataloged decimals name symbol total_supply)a

  @doc false
  def changeset(%Token{} = token, params \\ %{}) do
    token
    |> cast(params, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:contract_address)
    |> trim_name()
    |> unique_constraint(:contract_address_hash)
  end

  defp trim_name(%Changeset{valid?: false} = changeset), do: changeset

  defp trim_name(%Changeset{valid?: true} = changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :name, String.trim(name))
    end
  end

  @doc """
  Builds an `Ecto.Query` to fetch the cataloged tokens.

  These are tokens with cataloged field set to true and updated_at is earlier or equal than an hour ago.
  """
  def cataloged_tokens(minutes \\ 2880) do
    date_now = DateTime.utc_now()
    some_time_ago_date = DateTime.add(date_now, -:timer.minutes(minutes), :millisecond)

    from(
      token in __MODULE__,
      select: token.contract_address_hash,
      where: token.cataloged == true and token.updated_at <= ^some_time_ago_date
    )
  end
end
